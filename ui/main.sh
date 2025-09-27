#!/bin/bash

# Main Menu
main_menu() {
    show_banner
    
    echo -e "${YELLOW}Choose your installation method:${NC}"
    echo ""
    
    CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Guided Installation" \
        "Expert Mode" \
        "Exit")
    
    case $CHOICE in
        "Guided Installation")
            basic_setup
            ;;
        "Expert Mode")
            advanced_setup
            ;;
        "Exit")
            echo -e "${GREEN}Thank you for using FLAME OS Installer!${NC}"
            exit 0
            ;;
    esac
}
