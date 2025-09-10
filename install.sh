#!/usr/bin/env bash
set -euo pipefail

# FlameOS Installer - Main Entry Point
# Split into modular files for better organization

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules
source "$SCRIPT_DIR/src/config.sh"
source "$SCRIPT_DIR/src/ui.sh"
source "$SCRIPT_DIR/src/disk.sh"
source "$SCRIPT_DIR/src/partition.sh"
source "$SCRIPT_DIR/src/install.sh"
source "$SCRIPT_DIR/src/network.sh"
source "$SCRIPT_DIR/src/user.sh"
source "$SCRIPT_DIR/src/desktop.sh"
source "$SCRIPT_DIR/system-config.sh"

# Main installer flow
main() {
  check_root
  show_banner "FlameOS Installer"
  
  while true; do
    local choice
    choice=$(printf "Guided Installation\nAdvanced Mode\nExit" | eval "$FZF --prompt=\"Main Menu > \" --header=\"Choose installation mode\"") || {
      echo "Exiting installer..."
      exit 0
    }
    
    case "$choice" in
      "Guided Installation")
        guided_installation || true
        ;;
      "Advanced Mode")
        advanced_mode || true
        ;;
      "Exit")
        echo "Goodbye!"
        exit 0
        ;;
      *)
        echo "Goodbye!"
        exit 0
        ;;
    esac
  done
}

# Check if running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This installer must be run as root."
    echo "Please run: sudo ./install.sh"
    echo ""
    echo "The installer needs root privileges to:"
    echo "- Format and partition disks"
    echo "- Mount filesystems"
    echo "- Install packages"
    echo "- Configure system files"
    exit 1
  fi
}

# Run main function
main "$@"
