#!/bin/bash

# Network Detection
network_detection() {
    show_banner
    gum style --foreground 214 "Network Detection"
    echo ""
    
    if ping -c 1 8.8.8.8 &> /dev/null; then
        gum style --foreground 46 "Network connection detected"
        sleep 1
        user_creation
    else
        gum style --foreground 196 "No network connection found"
        gum style --foreground 214 "Opening network configuration..."
        sleep 1
        nmtui
        if ping -c 1 8.8.8.8 &> /dev/null; then
            gum style --foreground 46 "Network configured successfully"
            sleep 1
            user_creation
        else
            gum style --foreground 196 "Network still not available"
            
            CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
                "Try Again" \
                "Go Back to Previous Menu")
            
            case $CHOICE in
                "Try Again")
                    network_detection
                    ;;
                "Go Back to Previous Menu")
                    main_menu
                    ;;
            esac
        fi
    fi
}
