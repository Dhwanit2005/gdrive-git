#!/usr/bin/env python3

"""
Test Google Drive API credentials
"""

import os
import sys
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SCOPES = ['https://www.googleapis.com/auth/drive']

def test_credentials():
    """Test if Google Drive API credentials work"""
    
    if not os.path.exists('credentials.json'):
        print("❌ credentials.json not found!")
        print("Please download it from Google Cloud Console")
        return False
    
    print("✅ credentials.json found")
    
    try:
        # Authenticate
        creds = None
        if os.path.exists('token.json'):
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
                creds = flow.run_local_server(port=0)
            
            with open('token.json', 'w') as token:
                token.write(creds.to_json())
        
        # Test API connection
        service = build('drive', 'v3', credentials=creds)
        
        # List some files to test connection
        results = service.files().list(pageSize=5, fields="files(id, name)").execute()
        files = results.get('files', [])
        
        print("✅ Successfully connected to Google Drive!")
        print(f"✅ Found {len(files)} files in your Drive")
        
        if files:
            print("\nFirst few files:")
            for file in files:
                print(f"  - {file['name']}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == '__main__':
    test_credentials()
