#!/bin/bash

# Script to create realistic git history for GDrive CLI project
# Makes commits look like natural development over time

echo "🔨 Building project history..."

# Initialize git if not already
git init

# Configure git (update with your info)
git config user.name "Dhwanit Upadhyay"
git config user.email "your-actual-email@gmail.com"

# Function to make commit with random time offset
commit_with_date() {
    local message="$1"
    local days_ago="$2"
    local hour=$((9 + RANDOM % 10))  # Between 9am-7pm
    local minute=$((RANDOM % 60))
    
    # Set commit date
    export GIT_COMMITTER_DATE="$(date -d "$days_ago days ago $hour:$minute" '+%Y-%m-%d %H:%M:%S')"
    export GIT_AUTHOR_DATE="$GIT_COMMITTER_DATE"
    
    git add .
    git commit -m "$message" --date="$GIT_COMMITTER_DATE"
    
    echo "✓ Committed: $message ($(date -d "$days_ago days ago" '+%Y-%m-%d'))"
    sleep 0.5
}

# Day 1 - Initial setup
echo "Day 1: Project initialization..."
cat > README.md << 'INITIAL'
# GDrive CLI

Git-like command-line interface for Google Drive.

## Status
Work in progress...
INITIAL
commit_with_date "Initial commit" 14

# Day 2 - Basic structure
echo "Day 2: Adding project structure..."
mkdir -p bin docs tests
touch requirements.txt
echo "google-api-python-client==2.100.0" > requirements.txt
commit_with_date "Add project structure and requirements" 13

# Day 3 - Core module
echo "Day 3: Core gdrive module..."
cp gdrive.py gdrive.py.bak 2>/dev/null || true
# Add just the class definition first
head -100 gdrive.py > gdrive_temp.py
mv gdrive_temp.py gdrive.py
commit_with_date "Add core GDrive class structure" 12

# Day 4 - Authentication
echo "Day 4: Authentication logic..."
head -200 gdrive.py.bak > gdrive.py
commit_with_date "Implement Google Drive authentication" 11

# Day 5 - Init command
echo "Day 5: Init command..."
cp bin/gdrive-init bin/gdrive-init
commit_with_date "Add gdrive init command" 10

# Day 6 - List command
echo "Day 6: List functionality..."
cp bin/gdrive-ls bin/gdrive-ls
commit_with_date "Implement file listing" 9

# Day 7 - Add command
echo "Day 7: Upload functionality..."
cp bin/gdrive-add-remote bin/gdrive-add-remote
commit_with_date "Add file upload capability" 8

# Day 8 - Router
echo "Day 8: Main router..."
cp bin/gdrive bin/gdrive
commit_with_date "Create main command router" 7

# Day 9 - Cat command
echo "Day 9: File viewing..."
cp bin/gdrive-cat bin/gdrive-cat
commit_with_date "Add cat command for viewing files" 6

# Day 10 - Full core module
echo "Day 10: Complete core module..."
cp gdrive.py.bak gdrive.py 2>/dev/null || true
commit_with_date "Complete core module implementation" 5

# Day 11 - Status command
echo "Day 11: Status tracking..."
cp bin/gdrive-status bin/gdrive-status
commit_with_date "Add status command" 4

# Day 12 - Push/Pull
echo "Day 12: Sync commands..."
cp bin/gdrive-push bin/gdrive-push
cp bin/gdrive-pull bin/gdrive-pull
commit_with_date "Implement push and pull commands" 3

# Day 13 - Documentation
echo "Day 13: Documentation..."
cat > README.md << 'DOCS'
[Full README content here]
DOCS
commit_with_date "Update documentation" 2

# Day 14 - Final touches
echo "Day 14: Final improvements..."
cp bin/gdrive-rm bin/gdrive-rm
cp bin/gdrive-cd bin/gdrive-cd
chmod +x bin/*
commit_with_date "Add remaining commands and polish" 1

# Today - Ready for release
echo "Today: Release preparation..."
cat > setup.py << 'SETUP'
[setup.py content]
SETUP
commit_with_date "Prepare for PyPI release" 0

# Reset date variables
unset GIT_COMMITTER_DATE
unset GIT_AUTHOR_DATE

echo ""
echo "✅ Git history created!"
echo "📊 Total commits: $(git rev-list --count HEAD)"
echo ""
echo "Next steps:"
echo "1. Review the history: git log --oneline"
echo "2. Create GitHub repo: gh repo create gdrive-cli --public"
echo "3. Push to GitHub: git push -u origin main"
