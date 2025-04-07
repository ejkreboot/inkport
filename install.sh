#!/bin/bash

CONFIG_DIR=".remarkable"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Prompt for user input
read -p "Enter the IP address of your reMarkable: " HOST
read -p "Enter SSH username [default: root]: " USER
USER=${USER:-root}

# Confirm paths
mkdir -p "$CONFIG_DIR"

# Generate config.json
cat > "$CONFIG_FILE" <<EOF
{
  "host": "$RMK_HOST",
  "user": "$RMK_USER",
  "defaultIcon": "blank",
  "defaultOrientation": "portrait",
  "defaultCategories": ["paper"],
  "retryInterval": 3600
}
EOF

echo "✅ Configuration written to $CONFIG_FILE"

# Ask if user wants to install SSH key
read -p "Would you like to copy your SSH public key to the device? (y/n): " COPYKEY
if [[ "$COPYKEY" =~ ^[Yy]$ ]]; then
  if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    ssh-copy-id "$RMK_USER@$RMK_HOST" && echo "✅ SSH key installed."
  else
    echo "⚠️ SSH key not found at ~/.ssh/id_rsa.pub. Generate one using 'ssh-keygen' and run install again."
    exit 1
  fi
else
  echo "ℹ️  You can still use inkport if you already have passwordless SSH access."
fi

echo "✅ Installation complete. You can now run ./inkport.sh to import templates."
