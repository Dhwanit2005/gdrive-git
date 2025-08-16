#!/bin/bash

# GDrive CLI Installation Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

echo -e "${YELLOW}Installing GDrive CLI tools...${NC}"

# Check if running as root for system-wide install
if [[ $EUID -eq 0 ]]; then
    echo -e "${GREEN}Installing system-wide to $INSTALL_DIR${NC}"
else
    echo -e "${YELLOW}Not running as root. Will need sudo for system install.${NC}"
    echo "Alternatively, you can install to your home directory."
    read -p "Install system-wide (requires sudo) or to ~/bin? (system/home): " choice
    
    if [[ "$choice" == "home" ]]; then
        INSTALL_DIR="$HOME/bin"
        mkdir -p "$INSTALL_DIR"
        echo -e "${GREEN}Installing to $INSTALL_DIR${NC}"
        
        # Check if ~/bin is in PATH
        if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
            echo -e "${YELLOW}Adding $HOME/bin to PATH...${NC}"
            echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
            echo -e "${GREEN}Added to ~/.zshrc. Run 'source ~/.zshrc' or restart terminal.${NC}"
        fi
    else
        echo -e "${GREEN}Installing system-wide to $INSTALL_DIR${NC}"
    fi
fi

# Check if bin directory exists
if [[ ! -d "$BIN_DIR" ]]; then
    echo -e "${RED}Error: bin directory not found at $BIN_DIR${NC}"
    exit 1
fi

# Copy main module
echo "Copying gdrive.py module..."
if [[ "$INSTALL_DIR" == "/usr/local/bin" ]]; then
    sudo cp "$SCRIPT_DIR/gdrive.py" /usr/local/lib/gdrive.py 2>/dev/null || {
        sudo mkdir -p /usr/local/lib
        sudo cp "$SCRIPT_DIR/gdrive.py" /usr/local/lib/gdrive.py
    }
    MODULE_PATH="/usr/local/lib"
else
    cp "$SCRIPT_DIR/gdrive.py" "$INSTALL_DIR/gdrive.py"
    MODULE_PATH="$INSTALL_DIR"
fi

# Find all executable files in bin/
commands=()
for file in "$BIN_DIR"/*; do
    if [[ -f "$file" && -x "$file" ]]; then
        commands+=($(basename "$file"))
    fi
done

if [[ ${#commands[@]} -eq 0 ]]; then
    echo -e "${RED}Error: No executable files found in $BIN_DIR${NC}"
    exit 1
fi

echo "Found commands: ${commands[*]}"

# Copy each command
for cmd in "${commands[@]}"; do
    echo "Installing $cmd..."
    
    # Create a wrapper script that can find the module
    wrapper="#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '$MODULE_PATH')
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

"
    
    # Append the original script content (skip the shebang and sys.path modifications)
    tail -n +4 "$BIN_DIR/$cmd" | sed '/sys\.path\.insert/d' >> /tmp/gdrive_wrapper
    echo "$wrapper" > /tmp/gdrive_wrapper_final
    cat /tmp/gdrive_wrapper >> /tmp/gdrive_wrapper_final
    
    # Install the wrapper
    if [[ "$INSTALL_DIR" == "/usr/local/bin" ]]; then
        sudo cp /tmp/gdrive_wrapper_final "$INSTALL_DIR/$cmd"
        sudo chmod +x "$INSTALL_DIR/$cmd"
    else
        cp /tmp/gdrive_wrapper_final "$INSTALL_DIR/$cmd"
        chmod +x "$INSTALL_DIR/$cmd"
    fi
    
    # Clean up temp files
    rm -f /tmp/gdrive_wrapper /tmp/gdrive_wrapper_final
done

echo -e "${GREEN}✅ Installation complete!${NC}"
echo
echo "Installed commands:"
for cmd in "${commands[@]}"; do
    echo "  - $cmd"
done
echo
echo -e "${YELLOW}Usage:${NC}"
echo "  gdrive-init [folder-name]    # Initialize workspace"
echo "  gdrive-ls                    # List Drive files"
echo "  gdrive-add-remote <file>     # Upload file"
echo "  # ... and more as you implement them"
echo
echo -e "${YELLOW}Note:${NC} Most commands require being in a gdrive workspace directory"
echo "      (run 'gdrive-init' first in your project folder)"

if [[ "$INSTALL_DIR" == "$HOME/bin" ]]; then
    echo
    echo -e "${YELLOW}Don't forget to run: source ~/.zshrc${NC}"
fi
