#!/bin/bash

echo "Installing GDrive CLI..."

# Install location
INSTALL_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib"

# Copy Python module
sudo cp gdrive.py $LIB_DIR/

# Create wrapper for each command
for cmd in bin/gdrive*; do
    if [[ -f "$cmd" && -x "$cmd" ]]; then
        name=$(basename "$cmd")
        echo "Installing $name..."
        
        # Create wrapper that sets PYTHONPATH
        sudo tee $INSTALL_DIR/$name > /dev/null << 'WRAPPER'
#!/bin/bash
PYTHONPATH=/usr/local/lib /usr/local/lib/'''$name''' "$@"
WRAPPER
        
        # Copy actual script
        sudo cp "$cmd" $LIB_DIR/$name
        sudo chmod +x $INSTALL_DIR/$name
        sudo chmod +x $LIB_DIR/$name
    fi
done

echo "✅ Installation complete!"
echo "You can now use: gdrive init, gdrive add, gdrive ls, etc."
