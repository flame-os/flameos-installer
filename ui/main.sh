#!/bin/bash


# Text Size Configuration
configure_text_size() {
    show_banner
    gum style --foreground 212 "Text Size Configuration"
    echo ""
    
    SIZE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Small" \
        "Medium" \
        "Large")
    
    case $SIZE in
        "Small")
            setfont ter-112n || echo "Small font applied"
            ;;
        "Medium")
            setfont ter-116n || echo "Medium font applied"
            ;;
        "Large")
            setfont ter-132n || echo "Large font applied"
            ;;
    esac
    
    gum style --foreground 46 "Text size changed to: $SIZE"
    sleep 1
}

# Main Menu
main_menu() {
    show_banner
    
    echo -e "${YELLOW}Choose your installation method:${NC}"
    echo ""
    
    CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Guided Installation" \
        "Expert Mode" \
        "Configure Text Size" \
        "Exit")
    
    case $CHOICE in
        "Guided Installation")
            basic_setup
            ;;
        "Expert Mode")
            advanced_setup
            ;;
        "Configure Text Size")
            configure_text_size
            ;;
        "Exit")
            echo -e "${GREEN}Thank you for using AsiraOS Installer!${NC}"
            exit 0
            ;;
    esac
}
