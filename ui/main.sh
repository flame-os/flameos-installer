#!/bin/bash

# Main Menu
main_menu() {
    show_banner
    
    gum style --foreground 8 --align center --width 60 "Choose installation mode"
    echo ""
    
    CHOICE=$(gum choose --cursor-prefix "→ " --selected-prefix "● " \
        "🎯 Guided Installation" \
        "⚙️  Expert Mode" \
        "🔧 Configure Text Size" \
        "❌ Exit")
    
    case $CHOICE in
        "🎯 Guided Installation")
            basic_setup
            ;;
        "⚙️  Expert Mode")
            advanced_setup
            ;;
        "🔧 Configure Text Size")
            configure_text_size
            ;;
        "❌ Exit")
            gum style --foreground 46 --align center "Thank you for using AsiraOS!"
            exit 0
            ;;
    esac
}

# Text Size Configuration
configure_text_size() {
    show_banner
    gum style --foreground 39 --align center "Text Size"
    echo ""
    
    SIZE=$(gum choose --cursor-prefix "→ " --selected-prefix "● " \
        "Small" \
        "Medium" \
        "Large")
    
    case $SIZE in
        "Small") setfont ter-112n 2>/dev/null ;;
        "Medium") setfont ter-116n 2>/dev/null ;;
        "Large") setfont ter-132n 2>/dev/null ;;
    esac
    
    gum style --foreground 46 "✓ Applied $SIZE font"
    sleep 1
}
