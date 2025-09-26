#!/bin/bash

# Basic Setup Menu - Automatic step-by-step configuration
basic_setup() {
    show_banner
    echo -e "${GREEN}BASIC SETUP${NC}"
    echo -e "${YELLOW}Automatic step-by-step installation${NC}"
    echo ""
    
    gum style --foreground 205 "This will guide you through all installation steps automatically"
    
    CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Start Basic Setup" \
        "Back to Main Menu")
    
    case $CHOICE in
        "Start Basic Setup")
            basic_step_1_network
            ;;
        "Back to Main Menu")
            main_menu
            ;;
    esac
}

# Step 1: Network Detection
basic_step_1_network() {
    show_banner
    gum style --foreground 212 "Step 1/12: Network Detection"
    echo ""
    
    if ping -c 1 8.8.8.8 &> /dev/null; then
        gum style --foreground 46 "✓ Network connection detected"
        sleep 1
        basic_step_2_disk
    else
        gum style --foreground 196 "✗ No network connection found"
        gum style --foreground 214 "Opening network configuration..."
        sleep 1
        nmtui
        if ping -c 1 8.8.8.8 &> /dev/null; then
            gum style --foreground 46 "✓ Network configured successfully"
            sleep 1
            basic_step_2_disk
        else
            gum style --foreground 196 "Network still not available"
            gum input --placeholder "Press Enter to try again..."
            basic_step_1_network
        fi
    fi
}

# Step 2: Disk Selection
basic_step_2_disk() {
    show_banner
    gum style --foreground 212 "Step 2/12: Disk Configuration"
    echo ""
    
    # Call disk selection but override the return path
    BASIC_MODE=true
    disk_selection
}

# Step 3: Locale Selection
basic_step_3_locale() {
    show_banner
    gum style --foreground 212 "Step 3/12: Locale Selection"
    echo ""
    
    # Set default locale and continue
    echo "en_US.UTF-8" > /tmp/flameos/locale
    gum style --foreground 46 "✓ Locale set to: en_US.UTF-8"
    sleep 1
    basic_step_4_mirror
}

# Step 4: Mirror Selection
basic_step_4_mirror() {
    show_banner
    gum style --foreground 212 "Step 4/12: Mirror Selection"
    echo ""
    
    BASIC_MODE=true
    mirror_selection
}

# Step 5: Swap Configuration
basic_step_5_swap() {
    show_banner
    gum style --foreground 212 "Step 5/12: Swap Configuration"
    echo ""
    
    BASIC_MODE=true
    swap_config
}

# Step 6: Bootloader Selection
basic_step_6_bootloader() {
    show_banner
    gum style --foreground 212 "Step 6/12: Bootloader Selection"
    echo ""
    
    BASIC_MODE=true
    bootloader_selection
}

# Step 7: Kernel Selection
basic_step_7_kernel() {
    show_banner
    gum style --foreground 212 "Step 7/12: Kernel Selection"
    echo ""
    
    BASIC_MODE=true
    kernel_selection
}

# Step 8: User Creation
basic_step_8_user() {
    show_banner
    gum style --foreground 212 "Step 8/12: User Creation"
    echo ""
    
    BASIC_MODE=true
    user_creation
}

# Step 9: Hostname Selection
basic_step_9_hostname() {
    show_banner
    gum style --foreground 212 "Step 9/12: Hostname Selection"
    echo ""
    
    BASIC_MODE=true
    hostname_selection
}

# Step 10: Desktop Environment
basic_step_10_desktop() {
    show_banner
    gum style --foreground 212 "Step 10/12: Desktop Environment"
    echo ""
    
    BASIC_MODE=true
    desktop_selection
}

# Step 11: Package Selection
basic_step_11_packages() {
    show_banner
    gum style --foreground 212 "Step 11/12: Package Selection (Optional)"
    echo ""
    
    CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Select Additional Packages" \
        "Skip Package Selection")
    
    case $CHOICE in
        "Select Additional Packages")
            BASIC_MODE=true
            package_selection
            ;;
        "Skip Package Selection")
            basic_step_12_timezone
            ;;
    esac
}

# Step 12: Timezone Selection
basic_step_12_timezone() {
    show_banner
    gum style --foreground 212 "Step 12/12: Timezone Selection"
    echo ""
    
    BASIC_MODE=true
    timezone_selection
}

# Final Step: Install
basic_install() {
    show_banner
    gum style --foreground 212 "Installation Ready"
    echo ""
    
    install_system
}
