#!/bin/bash

# Moonlight Manual Installation Script
# This script automates the manual installation steps for Moonlight
# Based on instructions from: https://moonlight-mod.github.io/using/install/#manual-installations

set -e # Exit immediately if a command exits with a non-zero status

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to detect package manager and install dependencies
install_dependencies() {
  local deps=("$@")
  
  if command_exists apt-get; then
    echo "Detected apt package manager"
    sudo apt-get update
    sudo apt-get install -y "${deps[@]}"
  elif command_exists dnf; then
    echo "Detected dnf package manager"
    sudo dnf install -y "${deps[@]}"
  elif command_exists yum; then
    echo "Detected yum package manager"
    sudo yum install -y "${deps[@]}"
  elif command_exists pacman; then
    echo "Detected pacman package manager"
    sudo pacman -Sy --noconfirm "${deps[@]}"
  elif command_exists zypper; then
    echo "Detected zypper package manager"
    sudo zypper install -y "${deps[@]}"
  elif command_exists brew; then
    echo "Detected Homebrew package manager"
    brew install "${deps[@]}"
  else
    echo "Unable to detect package manager. Please install the following dependencies manually: ${deps[*]}"
    exit 1
  fi
}

# Function to check sudo access
check_sudo() {
  if ! command_exists sudo; then
    echo "Error: 'sudo' command not found. Please install sudo or run this script as root."
    exit 1
  fi
  
  # Check if user has sudo privileges
  if ! sudo -v &>/dev/null; then
    echo "Error: You need sudo privileges to install dependencies."
    exit 1
  fi
}

# Check for required dependencies
echo "Checking dependencies..."
DEPENDENCIES=(curl unzip)
NODE_DEPS=("node" "npm")
MISSING_DEPS=()
MISSING_NODE=false

# Check for non-Node dependencies
for DEP in "${DEPENDENCIES[@]}"; do
  if ! command_exists "$DEP"; then
    MISSING_DEPS+=("$DEP")
  fi
done

# Check for Node.js and npm separately
for DEP in "${NODE_DEPS[@]}"; do
  if ! command_exists "$DEP"; then
    MISSING_NODE=true
  fi
done

# Install missing dependencies if any
if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
  echo "Missing dependencies: ${MISSING_DEPS[*]}"
  read -p "Would you like to install them automatically? (y/n): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    check_sudo
    install_dependencies "${MISSING_DEPS[@]}"
  else
    echo "Please install the missing dependencies manually and run this script again."
    exit 1
  fi
fi

# Handle Node.js installation separately as it might need a different approach
if [ "$MISSING_NODE" = true ]; then
  echo "Node.js/npm is missing."
  read -p "Would you like to install Node.js automatically? (y/n): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    check_sudo
    
    if command_exists apt-get; then
      echo "Installing Node.js using apt..."
      curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
      sudo apt-get install -y nodejs
    elif command_exists dnf; then
      echo "Installing Node.js using dnf..."
      sudo dnf module install -y nodejs:18/default
    elif command_exists yum; then
      echo "Installing Node.js using yum..."
      curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
      sudo yum install -y nodejs
    elif command_exists pacman; then
      echo "Installing Node.js using pacman..."
      sudo pacman -Sy --noconfirm nodejs npm
    elif command_exists zypper; then
      echo "Installing Node.js using zypper..."
      sudo zypper install -y nodejs18
    elif command_exists brew; then
      echo "Installing Node.js using Homebrew..."
      brew install node@18
    else
      echo "Unable to install Node.js automatically. Please install Node.js v18 or higher manually."
      exit 1
    fi
  else
    echo "Please install Node.js v18 or higher manually and run this script again."
    exit 1
  fi
fi

# Add support for auto-reinstall mode
AUTO_REINSTALL=false
if [ "$1" = "--auto-reinstall" ] && [ -n "$2" ] && [ -n "$3" ]; then
  AUTO_REINSTALL=true
  MOONLIGHT_VERSION="$2"
  DISCORD_PATH="$3"
  echo "Running in auto-reinstall mode with Moonlight v$MOONLIGHT_VERSION"
  echo "Discord path: $DISCORD_PATH"
  
  # Check if Discord path exists
  if [ ! -d "$DISCORD_PATH" ]; then
    echo "Error: Discord path no longer exists. Please run the installer manually."
    exit 1
  fi
fi

# Check for Node.js version
if command_exists node; then
  NODE_VERSION=$(node -v | cut -d 'v' -f 2)
  NODE_MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d '.' -f 1)
  if [ "$NODE_MAJOR_VERSION" -lt 18 ]; then
    echo "Node.js version 18 or higher is required. Current version: $NODE_VERSION"
    read -p "Would you like to upgrade Node.js automatically? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      check_sudo
      # Upgrade Node.js based on package manager
      if command_exists apt-get; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
      elif command_exists dnf; then
        sudo dnf module reset -y nodejs
        sudo dnf module install -y nodejs:18/default
      elif command_exists brew; then
        brew upgrade node@18
      else
        echo "Unable to upgrade Node.js automatically. Please upgrade to Node.js v18 or higher manually."
        exit 1
      fi
    else
      echo "Please upgrade to Node.js v18 or higher manually and run this script again."
      exit 1
    fi
  fi
else
  echo "Error: Node.js is not installed even after attempting installation."
  exit 1
fi

# Define common Discord installation paths
COMMON_DISCORD_PATHS=(
  "/usr/share/discord"
  "/opt/discord"
  "$HOME/.local/share/discord"
  "$HOME/.config/discord"
  "/usr/share/discord-ptb"
  "/opt/discord-ptb"
  "$HOME/.local/share/discord-ptb"
  "$HOME/.config/discord-ptb"
  "/usr/share/discord-canary"
  "/opt/discord-canary"
  "$HOME/.local/share/discord-canary"
  "$HOME/.config/discord-canary"
)

# Check if any of the common paths exist
FOUND_PATHS=()
for path in "${COMMON_DISCORD_PATHS[@]}"; do
  if [ -d "$path" ]; then
    FOUND_PATHS+=("$path")
  fi
done

# Ask user to select Discord path or enter manually
DISCORD_PATH=""
if [ ${#FOUND_PATHS[@]} -gt 0 ]; then
  echo "Found Discord installations at the following locations:"
  for i in "${!FOUND_PATHS[@]}"; do
    echo "[$i] ${FOUND_PATHS[$i]}"
  done
  echo "[m] Enter path manually"
  
  read -p "Select an option: " DISCORD_CHOICE
  
  if [ "$DISCORD_CHOICE" = "m" ]; then
    read -p "Enter the path to your Discord installation: " DISCORD_PATH
  else
    DISCORD_PATH="${FOUND_PATHS[$DISCORD_CHOICE]}"
  fi
else
  echo "No Discord installation found in common locations."
  read -p "Enter the path to your Discord installation: " DISCORD_PATH
fi

# Check if path needs sudo
NEED_SUDO=false
if [ -d "$DISCORD_PATH" ] && [ ! -w "$DISCORD_PATH" ]; then
  echo "The Discord directory is not writable. You'll need sudo privileges to modify it."
  NEED_SUDO=true
  check_sudo
fi

# Validate Discord path
if [ ! -d "$DISCORD_PATH" ]; then
  echo "Error: The specified Discord path does not exist."
  exit 1
fi

# Find all app-* directories and let user select one if multiple exist
# First check if we're on macOS with a different structure
if [[ "$DISCORD_PATH" == *"Discord.app"* ]]; then
  # Check for macOS app structure
  if [ -d "$DISCORD_PATH/app" ]; then
    APP_DIRS=("$DISCORD_PATH/app")
  else
    # Look for traditional app-* directories just in case
    APP_DIRS=("$DISCORD_PATH"/app-*)
  fi
else
  # Traditional Linux/Windows Discord structure
  APP_DIRS=("$DISCORD_PATH"/app-*)
fi

if [ ${#APP_DIRS[@]} -eq 0 ] || [ ! -d "${APP_DIRS[0]}" ]; then
  echo "No app directories found in $DISCORD_PATH"
  echo "Checking alternative locations..."
  
  # Check if Discord uses a different structure
  if [ -d "$DISCORD_PATH/resources/app" ]; then
    echo "Found direct resources/app directory"
    APP_DIR="$DISCORD_PATH"
  elif [ -d "$DISCORD_PATH/modules" ]; then
    echo "Found modules directory, checking for Discord core module..."
    # This is for newer Discord versions that use modules
    MODULE_DIRS=("$DISCORD_PATH/modules/discord_desktop_core-"*)
    if [ ${#MODULE_DIRS[@]} -gt 0 ] && [ -d "${MODULE_DIRS[0]}" ]; then
      APP_DIR="${MODULE_DIRS[0]}"
    else
      echo "Error: Could not find Discord core module."
      exit 1
    fi
  else
    echo "Error: Could not identify Discord directory structure."
    exit 1
  fi
elif [ ${#APP_DIRS[@]} -eq 1 ]; then
  APP_DIR="${APP_DIRS[0]}"
else
  echo "Multiple Discord app directories found:"
  for i in "${!APP_DIRS[@]}"; do
    echo "[$i] ${APP_DIRS[$i]}"
  done
  read -p "Select the app directory number: " APP_DIR_INDEX
  APP_DIR="${APP_DIRS[$APP_DIR_INDEX]}"
fi

echo "Using Discord app directory: $APP_DIR"

# Ask for Moonlight version if not in auto-reinstall mode
if [ "$AUTO_REINSTALL" = false ]; then
  # Try to get latest version from GitHub API
  echo "Checking for latest Moonlight version..."
  if command_exists curl && command_exists jq; then
    LATEST_VERSION=$(curl -s https://api.github.com/repos/moonlight-mod/moonlight/releases/latest | jq -r .tag_name 2>/dev/null | sed 's/^v//')
    if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "null" ]; then
      read -p "Enter the Moonlight version to install (latest: $LATEST_VERSION): " MOONLIGHT_VERSION
      if [ -z "$MOONLIGHT_VERSION" ]; then
        MOONLIGHT_VERSION="$LATEST_VERSION"
        echo "Using latest version: $MOONLIGHT_VERSION"
      fi
    else
      read -p "Enter the Moonlight version to install (e.g., 2.1.0): " MOONLIGHT_VERSION
    fi
  else
    read -p "Enter the Moonlight version to install (e.g., 2.1.0): " MOONLIGHT_VERSION
  fi
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TEMP_DIR"

# Backup original Discord files
echo "Backing up original Discord files..."
BACKUP_DIR="$HOME/discord-backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r "$APP_DIR/resources/app" "$BACKUP_DIR/"
echo "Backup created at: $BACKUP_DIR"

# Download Moonlight
echo "Downloading Moonlight v$MOONLIGHT_VERSION..."
MOONLIGHT_URL="https://github.com/moonlight-mod/moonlight/releases/download/v$MOONLIGHT_VERSION/moonlight-v$MOONLIGHT_VERSION.zip"
curl -L "$MOONLIGHT_URL" -o "$TEMP_DIR/moonlight.zip"

# Extract Moonlight
echo "Extracting Moonlight..."
unzip -q "$TEMP_DIR/moonlight.zip" -d "$TEMP_DIR/moonlight"

# Check if resources/app directory exists
if [ ! -d "$APP_DIR/resources/app" ]; then
  echo "Error: resources/app directory not found in Discord installation."
  exit 1
fi

# Install Moonlight
echo "Installing Moonlight to Discord..."
if [ "$NEED_SUDO" = true ]; then
  echo "Using sudo to copy files..."
  sudo cp -r "$TEMP_DIR/moonlight/dist/"* "$APP_DIR/resources/app/"
else
  cp -r "$TEMP_DIR/moonlight/dist/"* "$APP_DIR/resources/app/"
fi

# Create core directory if it doesn't exist
mkdir -p "$HOME/.moonlight/core"

# Create default config if it doesn't exist
CONFIG_FILE="$HOME/.moonlight/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Creating default Moonlight configuration..."
  mkdir -p "$(dirname "$CONFIG_FILE")"
  cat > "$CONFIG_FILE" << EOF
{
  "plugins": {
    "installed": {}
  },
  "settings": {
    "general": {
      "developerMode": false
    }
  }
}
EOF
  echo "Created config file at $CONFIG_FILE"
fi

# Set appropriate permissions for the config directory
chmod -R 755 "$HOME/.moonlight"

# Clean up
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

# Set appropriate ownership if sudo was used
if [ "$NEED_SUDO" = true ]; then
  echo "Setting appropriate ownership for Discord files..."
  sudo chown -R "$(whoami)" "$APP_DIR/resources/app"
fi

# Create a reinstall script
REINSTALL_SCRIPT="$HOME/.moonlight/reinstall-moonlight.sh"
echo "Creating reinstall script at $REINSTALL_SCRIPT"
cat > "$REINSTALL_SCRIPT" << EOF
#!/bin/bash
# Auto-generated script to reinstall Moonlight v$MOONLIGHT_VERSION after Discord updates
# Run this script after Discord updates to reinstall Moonlight

# Reinstall command - this will run the script with the same version
$(dirname "$0")/../$(basename "$0") --auto-reinstall $MOONLIGHT_VERSION "$DISCORD_PATH"
EOF
chmod +x "$REINSTALL_SCRIPT"

echo "---------------------------------------------------------"
echo "Moonlight v$MOONLIGHT_VERSION has been successfully installed!"
echo "You can find your Moonlight configuration at: $HOME/.moonlight"
echo ""
echo "A reinstall script has been created at: $REINSTALL_SCRIPT"
echo "If Discord updates, you can run this script to reinstall Moonlight."
echo ""
echo "Installation complete! You can now start Discord and Moonlight should be loaded."
echo "LinuxCLI by PhoenixAceVFX, based on a framework of mine."
echo "---------------------------------------------------------"
