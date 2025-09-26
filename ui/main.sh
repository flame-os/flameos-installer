#!/bin/bash

# Main Menu
main_menu() {
    show_banner
    
    CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Basic Setup" \
        "Advanced Setup" \
        "Exit")
    
    case $CHOICE in
        "Basic Setup")
            basic_setup
            ;;
        "Advanced Setup")
            advanced_setup
            ;;
        "Exit")
            echo -e "${GREEN}Thank you for using FLAME OS Installer!${NC}"
            exit 0
            ;;
    esac
}
