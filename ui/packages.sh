#!/bin/bash
# FlameOS - The Future of Linux
# Copyright (c) 2024 FlameOS Team
# https://flame-os.github.io
# Licensed under GPL-3.0


# Package Selection
package_selection() {
    show_banner
    gum style --foreground 212 "Package Selection"
    echo ""
    
    # Show currently selected packages (unique only)
    if [ -f "/tmp/flameos/packages" ]; then
        gum style --foreground 212 "Selected packages:"
        sort /tmp/flameos/packages | uniq | tr '\n' ' '
        echo ""
        echo ""
    fi
    
    CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Search and Add Package" \
        "Clear All Packages" \
        "Continue to Next Step" \
        "Go Back to Advanced Menu")
    
    case $CHOICE in
        "Search and Add Package")
            search_and_add_package
            ;;
        "Clear All Packages")
            rm -f /tmp/flameos/packages
            gum style --foreground 205 "All packages cleared"
            sleep 1
            package_selection
            ;;
        "Continue to Next Step")
            if [ "$BASIC_MODE" = true ]; then
                source ./ui/basic.sh
                basic_step_12_timezone
            else
                advanced_setup
            fi
            ;;
        "Go Back to Advanced Menu")
            if [ "$BASIC_MODE" = true ]; then
                source ./ui/basic.sh
                basic_setup
            else
                advanced_setup
            fi
            ;;
    esac
}

# Search and Add Package
search_and_add_package() {
    show_banner
    gum style --foreground 205 "Search Packages"
    echo ""
    
    # Get all packages and use gum filter for live search
    SELECTED_PACKAGE=$(pacman -Slq | gum filter --placeholder="Type to search packages..." || true)
    
    if [ -n "$SELECTED_PACKAGE" ] && [ "$SELECTED_PACKAGE" != "" ]; then
        # Add to selected packages (avoid duplicates)
        if ! grep -q "^$SELECTED_PACKAGE$" /tmp/flameos/packages 2>/dev/null; then
            echo "$SELECTED_PACKAGE" >> /tmp/flameos/packages
            gum style --foreground 46 "Added: $SELECTED_PACKAGE"
            sleep 1
        else
            gum style --foreground 205 "Package already selected: $SELECTED_PACKAGE"
            sleep 1
        fi
    fi
    
    # Return to main package menu
    if [ "$BASIC_MODE" = true ]; then
        package_selection
    else
        package_selection
    fi
}
