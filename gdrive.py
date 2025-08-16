#!/usr/bin/env python3

"""
GDrive Core Module
Git-like version control system for Google Drive
"""

import os
import sys
import json
import hashlib
import sqlite3
import shutil
from datetime import datetime
from pathlib import Path
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
DB_FILE = os.path.join(GDRIVE_DIR, 'repo.db')

class GDriveError(Exception):
    """Custom exception for GDrive operations"""
    pass

class GDriveRepo:
    def __init__(self):
        self.service = None
        self.config = {}
        self.conn = None
        
        if os.path.exists(GDRIVE_DIR):
            self.load_config()
            self.authenticate()
            self.connect_db()
    
    def load_config(self):
        """Load repository configuration"""
        try:
            with open(CONFIG_FILE, 'r') as f:
                self.config = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            self.config = {}
    
    def save_config(self):
        """Save repository configuration"""
        with open(CONFIG_FILE, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def authenticate(self):
        """Authenticate with Google Drive API"""
        if not os.path.exists(CREDENTIALS_FILE):
            raise GDriveError(f"gdrive-init: error: {CREDENTIALS_FILE} not found")
        
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
        """Connect to SQLite database"""
        self.conn = sqlite3.connect(DB_FILE)
        self.init_tables()
    
    def init_tables(self):
        """Initialize database tables"""
        cursor = self.conn.cursor()
        
        # Files table - tracks file states
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS files (
                filename TEXT PRIMARY KEY,
                content_hash TEXT,
                status TEXT DEFAULT 'untracked',
                drive_id TEXT,
                last_synced TEXT
            )
        ''')
        
        # Commits table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS commits (
                commit_num INTEGER PRIMARY KEY,
                message TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                branch TEXT DEFAULT 'master'
            )
        ''')
        
        # Commit files table - snapshot of files at each commit
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS commit_files (
                commit_num INTEGER,
                filename TEXT,
                content_hash TEXT,
                FOREIGN KEY (commit_num) REFERENCES commits (commit_num)
            )
        ''')
        
        # Branches table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS branches (
                name TEXT PRIMARY KEY,
                commit_num INTEGER,
                FOREIGN KEY (commit_num) REFERENCES commits (commit_num)
            )
        ''')
        
        # Index table - staging area
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS index_files (
                filename TEXT PRIMARY KEY,
                content_hash TEXT
            )
        ''')
        
        self.conn.commit()
    
    def get_file_hash(self, filename):
        """Calculate SHA-1 hash of file contents"""
        if not os.path.exists(filename):
            return None
        
        hash_sha1 = hashlib.sha1()
        try:
            with open(filename, 'rb') as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_sha1.update(chunk)
            return hash_sha1.hexdigest()
        except IOError:
            return None
    
    def get_current_branch(self):
        """Get the current branch name"""
        return self.config.get('current_branch', 'master')
    
    def set_current_branch(self, branch_name):
        """Set the current branch"""
        self.config['current_branch'] = branch_name
        self.save_config()
    
    def get_next_commit_num(self):
        """Get the next commit number"""
        cursor = self.conn.cursor()
        cursor.execute('SELECT MAX(commit_num) FROM commits')
        result = cursor.fetchone()[0]
        return (result + 1) if result is not None else 0
    
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
    
    def upload_file_to_drive(self, filename, drive_folder_id):
        """Upload a file to Google Drive"""
        file_metadata = {'name': filename}
        if drive_folder_id:
            file_metadata['parents'] = [drive_folder_id]
        
        media = MediaFileUpload(filename, resumable=True)
        file = self.service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id'
        ).execute()
        
        return file.get('id')
    
    def update_file_in_drive(self, file_id, filename):
        """Update an existing file in Google Drive"""
        media = MediaFileUpload(filename, resumable=True)
        file = self.service.files().update(
            fileId=file_id,
            media_body=media,
            fields='id'
        ).execute()
        
        return file.get('id')
    
    def download_file_from_drive(self, file_id, filename):
        """Download a file from Google Drive"""
        request = self.service.files().get_media(fileId=file_id)
        file_io = io.BytesIO()
        downloader = MediaIoBaseDownload(file_io, request)
        
        done = False
        while not done:
            status, done = downloader.next_chunk()
        
        with open(filename, 'wb') as f:
            f.write(file_io.getvalue())
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()

def error_exit(program_name, message):
    """Print error message to stderr and exit with status 1"""
    print(f"{program_name}: error: {message}", file=sys.stderr)
    sys.exit(1)

def get_program_name():
    """Extract program name from sys.argv[0]"""
    return os.path.basename(sys.argv[0])

# Store files in .gdrive/objects using content-addressable storage
def store_file_object(filename, content_hash):
    """Store file contents in object store"""
    objects_dir = os.path.join(GDRIVE_DIR, 'objects')
    os.makedirs(objects_dir, exist_ok=True)
    
    object_path = os.path.join(objects_dir, content_hash)
    if not os.path.exists(object_path):
        shutil.copy2(filename, object_path)

def restore_file_object(content_hash, filename):
    """Restore file from object store"""
    object_path = os.path.join(GDRIVE_DIR, 'objects', content_hash)
    if os.path.exists(object_path):
        shutil.copy2(object_path, filename)
        return True
    return False
