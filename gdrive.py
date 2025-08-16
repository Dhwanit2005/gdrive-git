#!/usr/bin/env python3

"""
GDrive CLI Module
Command-line interface for Google Drive with Git-like commands
"""

import os
import sys
import json
import sqlite3
import re
from datetime import datetime
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload, MediaIoBaseDownload
import io

SCOPES = ['https://www.googleapis.com/auth/drive']
GDRIVE_DIR = '.gdrive'
CONFIG_FILE = os.path.join(GDRIVE_DIR, 'config.json')
TOKEN_FILE = os.path.join(GDRIVE_DIR, 'token.json')
CREDENTIALS_FILE = 'credentials.json'
SYNC_DB_FILE = os.path.join(GDRIVE_DIR, 'sync.db')

class GDriveError(Exception):
    """Custom exception for GDrive operations"""
    pass

class GDriveCLI:
    def __init__(self):
        self.service = None
        self.config = {}
        self.conn = None
        
        # Initialize if .gdrive directory exists
        if os.path.exists(GDRIVE_DIR):
            self.load_config()
            self.authenticate()
            self.connect_db()
    
    def init_workspace(self, folder_name=None):
        """Initialize GDrive workspace in current directory"""
        if os.path.exists(GDRIVE_DIR):
            raise GDriveError(f"{GDRIVE_DIR} already exists")
        
        # Create .gdrive directory
        os.makedirs(GDRIVE_DIR)
        
        # Authenticate and get Drive service
        self.authenticate()
        
        # Create or use existing Drive folder
        if folder_name:
            remote_folder_id = self.create_remote_folder(folder_name)
        else:
            folder_name = f"gdrive-{os.path.basename(os.getcwd())}"
            remote_folder_id = self.create_remote_folder(folder_name)
        
        # Save configuration
        self.config = {
            'remote_folder_id': remote_folder_id,
            'folder_name': folder_name,
            'created': datetime.now().isoformat(),
            'root_path': os.getcwd()
        }
        self.save_config()
        
        # Initialize sync database
        self.connect_db()
        
        return remote_folder_id
    
    def load_config(self):
        """Load workspace configuration"""
        try:
            with open(CONFIG_FILE, 'r') as f:
                self.config = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            self.config = {}
    
    def save_config(self):
        """Save workspace configuration"""
        os.makedirs(GDRIVE_DIR, exist_ok=True)
        with open(CONFIG_FILE, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def authenticate(self):
        """Authenticate with Google Drive API"""
        if not os.path.exists(CREDENTIALS_FILE):
            raise GDriveError(f"{CREDENTIALS_FILE} not found")
        
        creds = None
        if os.path.exists(TOKEN_FILE):
            creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
        
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
                creds = flow.run_local_server(port=0)
            
            with open(TOKEN_FILE, 'w') as token:
                token.write(creds.to_json())
        
        self.service = build('drive', 'v3', credentials=creds)
    
    def connect_db(self):
        """Connect to sync tracking database"""
        self.conn = sqlite3.connect(SYNC_DB_FILE)
        self.init_sync_tables()
    
    def init_sync_tables(self):
        """Initialize simplified sync tracking tables"""
        cursor = self.conn.cursor()
        
        # Sync files table - track local <-> remote file relationships
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS sync_files (
                local_path TEXT PRIMARY KEY,
                remote_id TEXT NOT NULL,
                remote_name TEXT,
                last_synced TEXT,
                local_modified TEXT,
                remote_modified TEXT
            )
        ''')
        
        self.conn.commit()
    
    # ===== GOOGLE DRIVE API OPERATIONS =====
    
    def list_drive_files(self, folder_id=None, name_filter=None, file_type=None):
        """List files in Google Drive"""
        query_parts = ["trashed=false"]
        
        if folder_id:
            query_parts.append(f"'{folder_id}' in parents")
        elif self.config.get('remote_folder_id'):
            query_parts.append(f"'{self.config['remote_folder_id']}' in parents")
        
        if name_filter:
            query_parts.append(f"name contains '{name_filter}'")
        
        if file_type:
            if file_type == 'folder':
                query_parts.append("mimeType='application/vnd.google-apps.folder'")
            elif file_type == 'document':
                query_parts.append("mimeType='application/vnd.google-apps.document'")
            elif file_type == 'sheet':
                query_parts.append("mimeType='application/vnd.google-apps.spreadsheet'")
        
        query = " and ".join(query_parts)
        
        results = self.service.files().list(
            q=query,
            pageSize=100,
            fields="files(id, name, mimeType, size, modifiedTime, parents)"
        ).execute()
        
        return results.get('files', [])
    
    def get_file_content(self, file_id):
        """Get file content as text (for cat command)"""
        try:
            # Try to get as text
            request = self.service.files().get_media(fileId=file_id)
            content = request.execute()
            return content.decode('utf-8')
        except Exception:
            # Try to export Google Docs as plain text
            try:
                request = self.service.files().export_media(
                    fileId=file_id, 
                    mimeType='text/plain'
                )
                content = request.execute()
                return content.decode('utf-8')
            except Exception as e:
                raise GDriveError(f"Cannot read file content: {e}")
    
    def create_remote_folder(self, folder_name):
        """Create a folder in Google Drive"""
        file_metadata = {
            'name': folder_name,
            'mimeType': 'application/vnd.google-apps.folder'
        }
        
        folder = self.service.files().create(
            body=file_metadata,
            fields='id'
        ).execute()
        
        return folder.get('id')
    
    def upload_file(self, local_path, remote_name=None, folder_id=None):
        """Upload a local file to Google Drive"""
        if not os.path.exists(local_path):
            raise GDriveError(f"Local file not found: {local_path}")
        
        file_metadata = {'name': remote_name or os.path.basename(local_path)}
        
        # Use configured folder if no folder specified
        if not folder_id and self.config.get('remote_folder_id'):
            folder_id = self.config['remote_folder_id']
        
        if folder_id:
            file_metadata['parents'] = [folder_id]
        
        media = MediaFileUpload(local_path, resumable=True)
        
        file = self.service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id, name, modifiedTime'
        ).execute()
        
        return file
    
    def download_file(self, file_id, local_path):
        """Download a file from Google Drive"""
        request = self.service.files().get_media(fileId=file_id)
        file_io = io.BytesIO()
        downloader = MediaIoBaseDownload(file_io, request)
        
        done = False
        while not done:
            status, done = downloader.next_chunk()
        
        # Save to local file
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        with open(local_path, 'wb') as f:
            f.write(file_io.getvalue())
        
        return True
    
    def delete_file(self, file_id):
        """Delete a file from Google Drive"""
        self.service.files().delete(fileId=file_id).execute()
        return True
    
    def get_file_metadata(self, file_id):
        """Get file metadata from Google Drive"""
        return self.service.files().get(
            fileId=file_id,
            fields='id, name, mimeType, size, modifiedTime, parents'
        ).execute()
    
    # ===== SYNC OPERATIONS =====
    
    def track_file(self, local_path, remote_id, remote_name):
        """Track a local file's relationship to remote file"""
        cursor = self.conn.cursor()
        
        local_modified = datetime.fromtimestamp(os.path.getmtime(local_path)).isoformat()
        
        cursor.execute('''
            INSERT OR REPLACE INTO sync_files 
            (local_path, remote_id, remote_name, last_synced, local_modified)
            VALUES (?, ?, ?, datetime('now'), ?)
        ''', (local_path, remote_id, remote_name, local_modified))
        
        self.conn.commit()
    
    def get_tracked_files(self):
        """Get all tracked file relationships"""
        cursor = self.conn.cursor()
        cursor.execute('SELECT * FROM sync_files')
        
        columns = [desc[0] for desc in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]
    
    def get_file_status(self, local_path):
        """Get sync status of a local file"""
        cursor = self.conn.cursor()
        cursor.execute(
            'SELECT * FROM sync_files WHERE local_path = ?',
            (local_path,)
        )
        
        result = cursor.fetchone()
        if not result:
            return None
        
        columns = [desc[0] for desc in cursor.description]
        return dict(zip(columns, result))
    
    def untrack_file(self, local_path):
        """Stop tracking a file"""
        cursor = self.conn.cursor()
        cursor.execute('DELETE FROM sync_files WHERE local_path = ?', (local_path,))
        self.conn.commit()
    
    # ===== UTILITY FUNCTIONS =====
    
    def extract_file_id(self, sharing_link_or_id):
        """Extract file ID from sharing link or return if already ID"""
        # If it's already a file ID (no slashes/domains)
        if '/' not in sharing_link_or_id and '.' not in sharing_link_or_id:
            return sharing_link_or_id
        
        # Extract from sharing link
        patterns = [
            r'/file/d/([a-zA-Z0-9-_]+)',
            r'id=([a-zA-Z0-9-_]+)',
            r'/folders/([a-zA-Z0-9-_]+)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, sharing_link_or_id)
            if match:
                return match.group(1)
        
        raise GDriveError(f"Could not extract file ID from: {sharing_link_or_id}")
    
    def format_file_size(self, size_bytes):
        """Format file size in human readable format"""
        if not size_bytes:
            return "N/A"
        
        try:
            size = int(size_bytes)
            for unit in ['B', 'KB', 'MB', 'GB']:
                if size < 1024:
                    return f"{size:.1f}{unit}"
                size /= 1024
            return f"{size:.1f}TB"
        except (ValueError, TypeError):
            return "N/A"
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()

# ===== UTILITY FUNCTIONS =====

def error_exit(program_name, message):
    """Print error message to stderr and exit with status 1"""
    print(f"{program_name}: error: {message}", file=sys.stderr)
    sys.exit(1)

def get_program_name():
    """Extract program name from sys.argv[0]"""
    return os.path.basename(sys.argv[0])

def requires_workspace(func):
    """Decorator to ensure commands run in a gdrive workspace"""
    def wrapper(*args, **kwargs):
        if not os.path.exists(GDRIVE_DIR):
            program_name = get_program_name()
            error_exit(program_name, "not in a gdrive workspace (run 'gdrive init' first)")
        return func(*args, **kwargs)
    return wrapper