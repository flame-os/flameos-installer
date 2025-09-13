#!/usr/bin/env bash

# FlameOS Installer - Kitty Terminal Launcher
# Run the installer in a kitty terminal window

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "Starting FlameOS Installer with sudo..."
    kitty -e sudo "$SCRIPT_DIR/install.sh"
else
    echo "Starting FlameOS Installer..."
    kitty -e "$SCRIPT_DIR/install.sh"
fi
