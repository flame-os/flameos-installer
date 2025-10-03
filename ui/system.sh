#!/bin/bash


# Locale Selection
locale_selection() {
    show_banner
    gum style --foreground 212 "Locale Selection"
    echo ""
    
    if [ -f "/tmp/asiraos/locale" ]; then
        gum style --foreground 46 "Current locale: $(cat /tmp/asiraos/locale)"
        echo ""
    fi
    
    LOCALE_OPTIONS=(
        "English (US) - en_US.UTF-8"
        "English (UK) - en_GB.UTF-8"
        "German (Germany) - de_DE.UTF-8"
        "French (France) - fr_FR.UTF-8"
        "Spanish (Spain) - es_ES.UTF-8"
        "Italian (Italy) - it_IT.UTF-8"
        "Portuguese (Brazil) - pt_BR.UTF-8"
        "Russian (Russia) - ru_RU.UTF-8"
        "Japanese (Japan) - ja_JP.UTF-8"
        "Chinese (China) - zh_CN.UTF-8"
    )
    
    SELECTED_OPTION=$(gum choose --cursor-prefix "> " --selected-prefix "* " "${LOCALE_OPTIONS[@]}")
    
    if [ -n "$SELECTED_OPTION" ]; then
        SELECTED_LOCALE=$(echo "$SELECTED_OPTION" | sed 's/.* - //')
        echo "$SELECTED_LOCALE" > /tmp/asiraos/locale
        gum style --foreground 46 "Selected locale: $SELECTED_LOCALE"
        sleep 1
    fi
    
    advanced_setup
}

# Swap Configuration
swap_config() {
    show_banner
    gum style --foreground 212 "Swap Configuration"
    echo ""
    
    if [ -f "/tmp/asiraos/swap" ]; then
        gum style --foreground 46 "Current swap: $(cat /tmp/asiraos/swap)"
        echo ""
    fi
    
    SWAP_CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Enable Swap (4GB)" \
        "Enable Swap (8GB)" \
        "Disable Swap")
    
    echo "$SWAP_CHOICE" > /tmp/asiraos/swap
    gum style --foreground 46 "Swap configuration: $SWAP_CHOICE"
    sleep 1
    
    # Handle basic mode progression
    if [ "$BASIC_MODE" = true ]; then
        source ./ui/basic.sh
        basic_step_6_bootloader
    else
        advanced_setup
    fi
}

# Bootloader Selection
bootloader_selection() {
    show_banner
    gum style --foreground 212 "Bootloader Selection"
    echo ""
    
    if [ -f "/tmp/asiraos/bootloader" ]; then
        gum style --foreground 46 "Current bootloader: $(cat /tmp/asiraos/bootloader)"
        echo ""
    fi
    
    BOOTLOADERS=("GRUB" "systemd-boot")
    
    SELECTED_BOOTLOADER=$(gum choose --cursor-prefix "> " --selected-prefix "* " "${BOOTLOADERS[@]}")
    
    if [ -n "$SELECTED_BOOTLOADER" ]; then
        echo "$SELECTED_BOOTLOADER" > /tmp/asiraos/bootloader
        gum style --foreground 46 "Selected bootloader: $SELECTED_BOOTLOADER"
        sleep 1
    fi
    
    # Handle basic mode progression
    if [ "$BASIC_MODE" = true ]; then
        source ./ui/basic.sh
        basic_step_7_kernel
    else
        advanced_setup
    fi
}

# Kernel Selection
kernel_selection() {
    show_banner
    gum style --foreground 212 "Kernel Selection"
    echo ""
    
    if [ -f "/tmp/asiraos/kernel" ]; then
        gum style --foreground 46 "Current kernel: $(cat /tmp/asiraos/kernel)"
        echo ""
    fi
    
    KERNELS=("linux" "linux-lts" "linux-zen" "linux-hardened")
    
    SELECTED_KERNEL=$(gum choose --cursor-prefix "> " --selected-prefix "* " "${KERNELS[@]}")
    
    if [ -n "$SELECTED_KERNEL" ]; then
        echo "$SELECTED_KERNEL" > /tmp/asiraos/kernel
        gum style --foreground 46 "Selected kernel: $SELECTED_KERNEL"
        sleep 1
    fi
    
    # Handle basic mode progression - NEVER go to advanced_setup
    if [ "$BASIC_MODE" = true ]; then
        source ./ui/basic.sh
        basic_step_8_user
    else
        advanced_setup
    fi
}

# Hostname Selection
hostname_selection() {
    show_banner
    gum style --foreground 212 "Hostname Selection"
    echo ""
    
    if [ -f "/tmp/asiraos/hostname" ]; then
        gum style --foreground 46 "Current hostname: $(cat /tmp/asiraos/hostname)"
        echo ""
    fi
    
    HOSTNAME=$(gum input --placeholder "Enter hostname (e.g., asiraos-pc)")
    
    if [ -n "$HOSTNAME" ]; then
        echo "$HOSTNAME" > /tmp/asiraos/hostname
        gum style --foreground 46 "Selected hostname: $HOSTNAME"
        sleep 1
    fi
    
    # Handle basic mode progression
    if [ "$BASIC_MODE" = true ]; then
        source ./ui/basic.sh
        basic_step_10_desktop
    else
        advanced_setup
    fi
}

# Desktop Environment Selection
desktop_selection() {
    show_banner
    gum style --foreground 212 "Desktop Environment Selection"
    echo ""
    
    if [ -f "/tmp/asiraos/desktop" ]; then
        gum style --foreground 46 "Current desktop: $(cat /tmp/asiraos/desktop)"
        echo ""
    fi
    
    DESKTOPS=("KDE Plasma" "GNOME" "XFCE" "i3wm" "Hyprland" "None (CLI only)")
    
    SELECTED_DESKTOP=$(gum choose --cursor-prefix "> " --selected-prefix "* " "${DESKTOPS[@]}")
    
    if [ -n "$SELECTED_DESKTOP" ]; then
        echo "$SELECTED_DESKTOP" > /tmp/asiraos/desktop
        gum style --foreground 46 "Selected desktop: $SELECTED_DESKTOP"
        sleep 1
    fi
    
    # Handle basic mode progression - NEVER go to advanced_setup
    if [ "$BASIC_MODE" = true ]; then
        source ./ui/basic.sh
        basic_step_11_drivers
    else
        advanced_setup
    fi
}

# Mirror Selection
mirror_selection() {
    show_banner
    gum style --foreground 212 "Mirror Selection"
    echo ""
    
    if [ -f "/tmp/asiraos/mirror" ]; then
        MIRROR_COUNTRY=$(cat /tmp/asiraos/mirror_country 2>/dev/null || echo "Unknown")
        gum style --foreground 46 "Current mirror: $MIRROR_COUNTRY"
        echo ""
    fi
    
    gum style --foreground 205 "Fetching mirror list from archlinux.org..."
    
    # Download and save mirrorlist
    curl -s "https://archlinux.org/mirrorlist/all/" > /tmp/mirrorlist.txt
    
    if [ ! -s /tmp/mirrorlist.txt ]; then
        gum style --foreground 196 "Failed to fetch mirrors, using fallback list"
        # Fallback mirrors
        declare -A COUNTRY_MIRRORS
        COUNTRY_MIRRORS["United States"]="https://mirrors.kernel.org/archlinux/\$repo/os/\$arch"
        COUNTRY_MIRRORS["Germany"]="https://mirror.f4st.host/archlinux/\$repo/os/\$arch"
        COUNTRY_MIRRORS["India"]="https://mirror.albony.in/archlinux/\$repo/os/\$arch"
    else
        gum style --foreground 46 "Successfully fetched mirrorlist"
        
        # Parse mirrorlist by country
        declare -A COUNTRY_MIRRORS
        declare -A INDIA_MIRRORS
        CURRENT_COUNTRY=""
        
        while IFS= read -r line; do
            # Match country lines like "## Australia"
            if [[ $line =~ ^##[[:space:]]*([^[:space:]].*)$ ]]; then
                CURRENT_COUNTRY="${BASH_REMATCH[1]}"
            # Match server lines and uncomment them
            elif [[ $line =~ ^#Server[[:space:]]*=[[:space:]]*(.+)$ ]] && [ -n "$CURRENT_COUNTRY" ]; then
                if [ "$CURRENT_COUNTRY" = "India" ]; then
                    # Store all Indian mirrors
                    INDIA_MIRRORS["${#INDIA_MIRRORS[@]}"]="${BASH_REMATCH[1]}"
                else
                    # Only take first mirror per other countries
                    if [ -z "${COUNTRY_MIRRORS[$CURRENT_COUNTRY]}" ]; then
                        COUNTRY_MIRRORS["$CURRENT_COUNTRY"]="${BASH_REMATCH[1]}"
                    fi
                fi
            fi
        done < /tmp/mirrorlist.txt
        
        # Add all Indian mirrors to country list
        if [ ${#INDIA_MIRRORS[@]} -gt 0 ]; then
            COUNTRY_MIRRORS["India"]="${INDIA_MIRRORS[0]}"
        fi
        
        # Clean up
        rm -f /tmp/mirrorlist.txt
    fi
    
    if [ ${#COUNTRY_MIRRORS[@]} -eq 0 ]; then
        gum style --foreground 196 "No mirrors found, using default"
        COUNTRY_MIRRORS["United States"]="https://mirrors.kernel.org/archlinux/\$repo/os/\$arch"
    fi
    
    gum style --foreground 46 "Found ${#COUNTRY_MIRRORS[@]} countries"
    
    # Use gum filter for live search
    SELECTED_COUNTRY=$(printf '%s\n' "${!COUNTRY_MIRRORS[@]}" | sort | gum filter --placeholder="Search countries..." || true)
    
    if [ -n "$SELECTED_COUNTRY" ]; then
        if [ "$SELECTED_COUNTRY" = "India" ] && [ ${#INDIA_MIRRORS[@]} -gt 0 ]; then
            # Add all Indian mirrors to mirrorlist
            gum style --foreground 205 "Adding all Indian mirrors..."
            > /tmp/asiraos/mirror
            for i in "${!INDIA_MIRRORS[@]}"; do
                echo "Server = ${INDIA_MIRRORS[$i]}" >> /tmp/asiraos/mirror
            done
            echo "$SELECTED_COUNTRY" > /tmp/asiraos/mirror_country
            gum style --foreground 46 "Added ${#INDIA_MIRRORS[@]} Indian mirrors"
        else
            SELECTED_MIRROR="${COUNTRY_MIRRORS[$SELECTED_COUNTRY]}"
            echo "Server = $SELECTED_MIRROR" > /tmp/asiraos/mirror
            echo "$SELECTED_COUNTRY" > /tmp/asiraos/mirror_country
            gum style --foreground 46 "Selected mirror: $SELECTED_COUNTRY"
        fi
        sleep 1
    fi
    
    # Handle basic mode progression
    if [ "$BASIC_MODE" = true ]; then
        source ./ui/basic.sh
        basic_step_5_swap
    else
        advanced_setup
    fi
}

# Timezone Selection
timezone_selection() {
    show_banner
    gum style --foreground 212 "Timezone Selection"
    echo ""
    
    if [ -f "/tmp/asiraos/timezone" ]; then
        gum style --foreground 46 "Current timezone: $(cat /tmp/asiraos/timezone)"
        echo ""
    fi
    
    # Get all available timezones in searchable format
    gum style --foreground 205 "Building timezone list..."
    TIMEZONES=()
    
    # Get all timezone files and format them as Region/City
    while IFS= read -r -d '' file; do
        # Remove /usr/share/zoneinfo/ prefix and add to array
        TIMEZONE="${file#/usr/share/zoneinfo/}"
        # Skip files without / (like UTC, GMT, etc.) and posix/right directories
        if [[ "$TIMEZONE" =~ ^[A-Z][a-z_]+/[A-Za-z_-]+$ ]]; then
            TIMEZONES+=("$TIMEZONE")
        fi
    done < <(find /usr/share/zoneinfo -type f -name "*" -print0 | grep -zv -E "(posix|right|leap|Factory)")
    
    # Sort timezones
    IFS=$'\n' TIMEZONES=($(sort <<<"${TIMEZONES[*]}"))
    
    gum style --foreground 46 "Found ${#TIMEZONES[@]} timezones"
    
    # Use gum filter for searchable timezone selection
    SELECTED_TIMEZONE=$(printf '%s\n' "${TIMEZONES[@]}" | gum filter --placeholder="Search timezones (e.g., Asia/Kolkata, Europe/London)..." || true)
    
    if [ -n "$SELECTED_TIMEZONE" ]; then
        echo "$SELECTED_TIMEZONE" > /tmp/asiraos/timezone
        gum style --foreground 46 "Selected timezone: $SELECTED_TIMEZONE"
        sleep 1
    fi
    
    # Handle basic mode progression
    if [ "$BASIC_MODE" = true ]; then
        source ./ui/basic.sh
        basic_install
    else
        advanced_setup
    fi
}

# Install System
install_system() {
    show_banner
    gum style --foreground 212 "Install AsiraOS"
    echo ""
    
    gum style --foreground 205 "Ready to install AsiraOS with your configuration!"
    echo ""
    
    CONFIRM=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "→ Start Installation" \
        "Go Back to Configuration")
    
    if [ "$CONFIRM" = "→ Start Installation" ]; then
        perform_installation
    else
        if [ "$BASIC_MODE" = true ]; then
            source ./ui/basic.sh
            basic_setup
        else
            advanced_setup
        fi
    fi
}

# Perform the actual installation
perform_installation() {
    show_banner
    gum style --foreground 212 "Installing AsiraOS..."
    echo ""
    
    # Load configuration
    KERNEL=$(cat /tmp/asiraos/kernel 2>/dev/null || echo "linux")
    HOSTNAME=$(cat /tmp/asiraos/hostname 2>/dev/null || echo "asiraos")
    DESKTOP=$(cat /tmp/asiraos/desktop 2>/dev/null || echo "None (CLI only)")
    TIMEZONE=$(cat /tmp/asiraos/timezone 2>/dev/null || echo "UTC")
    LOCALE=$(cat /tmp/asiraos/locale 2>/dev/null || echo "en_US.UTF-8")
    MIRROR=$(cat /tmp/asiraos/mirror 2>/dev/null)
    
    # Mount partitions
    gum style --foreground 205 "Mounting partitions..."
    
    # Unmount any existing mounts
    umount -R /mnt 2>/dev/null || true
    
    # Mount root partition first
    ROOT_PARTITION=$(grep " -> /$" /tmp/asiraos/mounts | cut -d' ' -f1 | head -1)
    if [ -n "$ROOT_PARTITION" ]; then
        gum style --foreground 46 "Mounting root: $ROOT_PARTITION -> /mnt"
        mount "$ROOT_PARTITION" /mnt
    else
        gum style --foreground 196 "Error: No root partition found!"
        gum input --placeholder "Press Enter to go back..."
        return
    fi
    
    # Mount other partitions
    while IFS= read -r line; do
        PARTITION=$(echo "$line" | cut -d' ' -f1)
        MOUNTPOINT=$(echo "$line" | cut -d' ' -f3)
        
        # Skip root partition (already mounted) and swap
        if [ "$MOUNTPOINT" = "/" ] || [ "$MOUNTPOINT" = "swap" ]; then
            continue
        fi
        
        # Create mountpoint and mount
        mkdir -p "/mnt$MOUNTPOINT"
        gum style --foreground 46 "Mounting: $PARTITION -> /mnt$MOUNTPOINT"
        
        if [ "$MOUNTPOINT" = "/boot/efi" ]; then
            mount -t vfat "$PARTITION" "/mnt$MOUNTPOINT"
        else
            mount "$PARTITION" "/mnt$MOUNTPOINT"
        fi
    done < /tmp/asiraos/mounts
    
    # Enable swap if configured
    SWAP_PARTITION=$(grep " -> swap$" /tmp/asiraos/mounts | cut -d' ' -f1 | head -1)
    if [ -n "$SWAP_PARTITION" ]; then
        gum style --foreground 46 "Enabling swap: $SWAP_PARTITION"
        swapon "$SWAP_PARTITION"
    fi
    
    # Step 1: Install base packages
    gum style --foreground 205 "Step 1/5: Installing base packages..."
    pacstrap /mnt base base-devel $KERNEL linux-firmware --noconfirm --needed
    
    # Step 2: Install dependencies and drivers
    gum style --foreground 205 "Step 2/5: Installing dependencies and drivers..."
    DRIVER_PACKAGES=$(get_driver_packages)
    pacstrap /mnt networkmanager network-manager-applet wireless_tools bluez bluez-utils blueman git $DRIVER_PACKAGES --noconfirm --needed
    
    # Step 3: Bootloader installation
    gum style --foreground 205 "Step 3/5: Installing bootloader..."
    
    # Check if system is EFI or BIOS
    if [ -d /sys/firmware/efi ]; then
        # EFI system
        pacstrap /mnt grub efibootmgr os-prober --noconfirm --needed
        
        # Check boot partition mount point
        if grep -q "/boot/efi" /tmp/asiraos/mounts; then
            arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=AsiraOS
        elif grep -q "/boot" /tmp/asiraos/mounts; then
            arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=AsiraOS
        fi
    else
        # BIOS system
        pacstrap /mnt grub os-prober --noconfirm --needed
        
        # Get root partition device (remove partition number)
        ROOT_DEVICE=$(grep " / " /tmp/asiraos/mounts | cut -d' ' -f1 | sed 's/[0-9]*$//')
        arch-chroot /mnt grub-install "$ROOT_DEVICE"
    fi
    
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    
    # Step 4: Generate fstab
    gum style --foreground 205 "Step 4/5: Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    
    # Step 5: Chroot and continue installation
    gum style --foreground 205 "Step 5/5: Configuring system..."
    
    # Copy desktop scripts and AsiraOS configuration
    if [ -d "modules" ]; then
        cp -r modules /mnt/
        chmod +x /mnt/modules/*.sh
        gum style --foreground 46 "Copied modules directory"
    else
        gum style --foreground 196 "Error: modules directory not found"
    fi
    
    # Copy AsiraOS configuration script
    if [ -f "lib/asiraos-config.sh" ]; then
        cp lib/asiraos-config.sh /mnt/
        chmod +x /mnt/asiraos-config.sh
        gum style --foreground 46 "Copied asiraos-config.sh"
    else
        gum style --foreground 196 "Error: lib/asiraos-config.sh not found"
    fi
    
    # Copy AsiraOS logo - check if /boot/efi is mounted separately
    if [ -f "lib/asiraos.png" ]; then
        if grep -q "/boot/efi" /tmp/asiraos/mounts; then
            mkdir -p /mnt/efi/grub/themes/shared
            cp lib/asiraos.png /mnt/efi/grub/themes/shared/
            gum style --foreground 46 "Copied asiraos.png to /efi/grub/themes/shared/"
        else
            mkdir -p /mnt/boot/grub/themes/shared
            cp lib/asiraos.png /mnt/boot/grub/themes/shared/
            gum style --foreground 46 "Copied asiraos.png to /boot/grub/themes/shared/"
        fi
    else
        gum style --foreground 196 "Error: lib/asiraos.png not found"
    fi
    cp lib/asiraos.png /mnt/etc/grub.d/
    # Install additional packages if selected
    if [ -f "/tmp/asiraos/packages" ]; then
        PACKAGES=$(cat /tmp/asiraos/packages | tr '\n' ' ')
        if [ -n "$PACKAGES" ]; then
            pacstrap /mnt $PACKAGES --noconfirm --needed
        fi
    fi
    
    # Create installation script
    cat <<REALEND > /mnt/next.sh
#!/bin/bash

# Set mirror if selected
if [ -f "/tmp/asiraos/mirror" ]; then
    cp /tmp/asiraos/mirror /etc/pacman.d/mirrorlist
fi

# Create user
useradd -m $USERNAME
usermod -aG wheel,storage,power,audio $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers

# Setup locale
sed -i 's/#$LOCALE/$LOCALE/g' /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
export LANG=$LOCALE

# Setup timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Setup hostname
echo "$HOSTNAME" > /etc/hostname

cat <<EOF > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

# Enable services
systemctl enable NetworkManager
systemctl enable bluetooth

# Configure AsiraOS system
bash /asiraos-config.sh

# Desktop environment installation
case "$DESKTOP" in  
    "Hyprland")
        bash /modules/hyprland.sh
        ;; 
    "KDE Plasma")
        bash /modules/kde.sh
        ;;
    "GNOME")
        bash /modules/gnome.sh
        ;;
    "XFCE")
        bash /modules/xfce.sh
        ;;
    "i3wm")
        bash /modules/i3wm.sh
        ;;
    "None (CLI only)")
        echo "No desktop environment selected"
        ;;
esac

echo "Installation completed successfully!"
REALEND

    # Execute the installation script
    arch-chroot /mnt bash /next.sh
    
    # Cleanup
    rm /mnt/next.sh
    rm /mnt/asiraos-config.sh
    rm -rf /mnt/modules
    
    gum style --foreground 46 "Installation completed successfully!"
    gum style --foreground 205 "AsiraOS has been installed successfully!"
    echo ""
    
    CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Yes" \
        "No")
    
    case $CHOICE in
        "Yes")
            gum style --foreground 214 "Rebooting in 3 seconds..."
            sleep 3
            reboot
            ;;
        "Exit to Shell")
            gum style --foreground 46 "Installation complete. You can manually reboot when ready."
            exit 0
            ;;
    esac
}
