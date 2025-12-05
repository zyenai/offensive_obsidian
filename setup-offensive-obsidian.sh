#!/bin/bash

################################################################################
# Offensive Obsidian Setup Script
# Automates installation and configuration of Obsidian for pentest note-taking
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Installation Functions
################################################################################

install_obsidian_linux() {
    print_info "Detecting Linux distribution..."

    if [ -f /etc/debian_version ]; then
        print_info "Debian-based system detected. Installing Obsidian..."

        # Check if obsidian is already installed
        if check_command obsidian; then
            print_warning "Obsidian is already installed."
            obsidian --version || true
            read -p "Do you want to reinstall? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Skipping Obsidian installation."
                return 0
            fi
        fi

        # Download latest Obsidian .deb
        print_info "Downloading Obsidian..."
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"

        # Get latest release URL
        OBSIDIAN_URL="https://github.com/obsidianmd/obsidian-releases/releases/latest/download/obsidian_amd64.deb"

        if wget -q "$OBSIDIAN_URL" -O obsidian.deb; then
            print_success "Downloaded Obsidian package"
        else
            print_error "Failed to download Obsidian. Please download manually from https://obsidian.md/download"
            return 1
        fi

        # Install the package
        print_info "Installing Obsidian (requires sudo)..."
        if sudo apt install -y ./obsidian.deb; then
            print_success "Obsidian installed successfully"
        else
            print_error "Failed to install Obsidian"
            return 1
        fi

        # Cleanup
        cd - > /dev/null
        rm -rf "$TEMP_DIR"

    elif [ -f /etc/redhat-release ]; then
        print_warning "Red Hat-based system detected."
        print_info "Please download and install Obsidian AppImage from https://obsidian.md/download"
        read -p "Press Enter once you have installed Obsidian..."

    elif [ -f /etc/arch-release ]; then
        print_info "Arch-based system detected."
        if check_command yay; then
            yay -S obsidian
        elif check_command paru; then
            paru -S obsidian
        else
            print_warning "Please install Obsidian using your AUR helper or download from https://obsidian.md/download"
            read -p "Press Enter once you have installed Obsidian..."
        fi
    else
        print_warning "Unknown Linux distribution."
        print_info "Please download and install Obsidian from https://obsidian.md/download"
        read -p "Press Enter once you have installed Obsidian..."
    fi
}

create_vault() {
    print_header "Create Obsidian Vault"

    echo "Enter the full path for your Obsidian vault"
    echo "Example: $HOME/Documents/PentestVault"
    read -p "Vault path: " VAULT_PATH

    # Expand ~ to home directory
    VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

    if [ -d "$VAULT_PATH" ]; then
        print_warning "Directory already exists: $VAULT_PATH"
        read -p "Use this existing directory as vault? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Vault creation cancelled."
            return 1
        fi
    else
        mkdir -p "$VAULT_PATH"
        print_success "Created vault directory: $VAULT_PATH"
    fi

    # Create .obsidian directory if it doesn't exist
    mkdir -p "$VAULT_PATH/.obsidian"
    mkdir -p "$VAULT_PATH/.obsidian/snippets"
    mkdir -p "$VAULT_PATH/.obsidian/plugins"

    print_success "Vault structure created"
}

copy_config_files() {
    print_header "Copying Configuration Files"

    if [ ! -d "$VAULT_PATH" ]; then
        print_error "Vault path not set. Please create vault first."
        return 1
    fi

    # Copy templates
    print_info "Copying templates..."
    if [ -d "$SCRIPT_DIR/config/templates" ]; then
        mkdir -p "$VAULT_PATH/config/templates"
        cp -r "$SCRIPT_DIR/config/templates/"* "$VAULT_PATH/config/templates/"
        print_success "Templates copied to $VAULT_PATH/config/templates/"
    else
        print_error "Templates directory not found: $SCRIPT_DIR/config/templates"
        return 1
    fi

    # Copy CSS snippets
    print_info "Copying CSS snippets..."
    if [ -d "$SCRIPT_DIR/config/css" ]; then
        cp "$SCRIPT_DIR/config/css/"*.css "$VAULT_PATH/.obsidian/snippets/"
        print_success "CSS snippets copied to $VAULT_PATH/.obsidian/snippets/"
    else
        print_error "CSS directory not found: $SCRIPT_DIR/config/css"
        return 1
    fi
}

configure_obsidian_settings() {
    print_header "Configuring Obsidian Settings"

    # Create or update community-plugins.json
    COMMUNITY_PLUGINS_FILE="$VAULT_PATH/.obsidian/community-plugins.json"

    print_info "Enabling community plugins..."
    cat > "$COMMUNITY_PLUGINS_FILE" << 'EOF'
[
  "templater-obsidian",
  "obsidian-automatic-table-of-contents"
]
EOF
    print_success "Community plugins configuration created"

    # Create hotkeys.json
    HOTKEYS_FILE="$VAULT_PATH/.obsidian/hotkeys.json"

    print_info "Configuring hotkeys..."
    cat > "$HOTKEYS_FILE" << 'EOF'
{
  "templater-obsidian:insert-templater": [
    {
      "modifiers": [
        "Mod",
        "Shift"
      ],
      "key": "A"
    }
  ],
  "obsidian-automatic-table-of-contents:insert-table-of-contents": [
    {
      "modifiers": [
        "Mod",
        "Shift"
      ],
      "key": "T"
    }
  ]
}
EOF
    print_success "Hotkeys configured (Ctrl+Shift+A for activity log template)"

    # Configure Templater settings
    TEMPLATER_DIR="$VAULT_PATH/.obsidian/plugins/templater-obsidian"
    mkdir -p "$TEMPLATER_DIR"

    cat > "$TEMPLATER_DIR/data.json" << EOF
{
  "command_timeout": 5,
  "templates_folder": "config/templates",
  "templates_pairs": [
    ["", ""]
  ],
  "trigger_on_file_creation": false,
  "enable_system_commands": false,
  "shell_path": "",
  "user_scripts_folder": "",
  "enable_folder_templates": true,
  "folder_templates": [
    {
      "folder": "",
      "template": ""
    }
  ],
  "syntax_highlighting": true,
  "enabled_templates_hotkeys": [
    "config/templates/pentest-activity-log.md",
    "config/templates/pentest-outbrief.md"
  ],
  "startup_templates": []
}
EOF
    print_success "Templater plugin configured"

    # Enable CSS snippets
    APPEARANCE_FILE="$VAULT_PATH/.obsidian/appearance.json"

    print_info "Enabling CSS snippets..."
    cat > "$APPEARANCE_FILE" << 'EOF'
{
  "cssTheme": "",
  "enabledCssSnippets": [
    "formats",
    "callout-10vh",
    "callout-15vh",
    "callout-25ch",
    "callout-50vh"
  ]
}
EOF
    print_success "CSS snippets enabled"
}

install_plugins_manually() {
    print_header "Plugin Installation Instructions"

    print_warning "The following plugins need to be installed manually from within Obsidian:"
    echo ""
    echo "1. Open Obsidian and open your vault: $VAULT_PATH"
    echo "2. Go to Settings → Community plugins"
    echo "3. Disable Safe Mode (if enabled)"
    echo "4. Click 'Browse' and install the following plugins:"
    echo "   - Templater by SilentVoid13"
    echo "   - Automatic Table of Contents by johansatge"
    echo "5. Enable both plugins after installation"
    echo ""
    print_info "The plugins are already configured in your vault settings."
}

setup_hotkeys_manual() {
    print_header "Manual Hotkey Configuration"

    print_info "Additional hotkeys to configure manually in Obsidian:"
    echo ""
    echo "1. Go to Settings → Hotkeys"
    echo "2. Search for 'Templater: Insert config/templates/pentest-outbrief.md'"
    echo "3. Set hotkey: Ctrl+Shift+O"
    echo ""
    print_success "Note: Ctrl+Shift+A is already configured for pentest-activity-log"
}

print_completion_message() {
    print_header "Setup Complete!"

    echo ""
    print_success "Offensive Obsidian has been configured!"
    echo ""
    echo "Vault location: $VAULT_PATH"
    echo ""
    print_info "Next Steps:"
    echo "1. Open Obsidian"
    echo "2. Open the vault at: $VAULT_PATH"
    echo "3. Install the community plugins (see instructions above)"
    echo "4. Configure the outbrief template hotkey (see instructions above)"
    echo ""
    print_info "Usage:"
    echo "- Press Ctrl+Shift+A to insert an activity log entry"
    echo "- Press Ctrl+Shift+O to insert an outbrief template"
    echo "- Press Ctrl+Shift+T to insert table of contents"
    echo ""
    print_success "Happy pentesting! 🔒"
}

################################################################################
# Main Script
################################################################################

main() {
    clear
    print_header "Offensive Obsidian Setup Script"
    echo "This script will install and configure Obsidian for pentest note-taking"
    echo ""

    # Check if running on Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_warning "This script is designed for Linux systems."
        print_info "For Windows, please follow the manual installation steps in README.md"
        exit 1
    fi

    # Install Obsidian
    print_header "Step 1: Install Obsidian"
    install_obsidian_linux
    echo ""

    # Create vault
    print_header "Step 2: Create Vault"
    create_vault
    echo ""

    # Copy configuration files
    print_header "Step 3: Copy Configuration"
    copy_config_files
    echo ""

    # Configure settings
    print_header "Step 4: Configure Settings"
    configure_obsidian_settings
    echo ""

    # Manual steps
    install_plugins_manually
    echo ""

    setup_hotkeys_manual
    echo ""

    # Completion message
    print_completion_message

    # Ask if user wants to open Obsidian
    echo ""
    read -p "Would you like to open Obsidian now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if check_command obsidian; then
            print_info "Opening Obsidian..."
            obsidian "$VAULT_PATH" &
            disown
        else
            print_error "Obsidian command not found. Please open it manually."
        fi
    fi
}

# Run main function
main "$@"
