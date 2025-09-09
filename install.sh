#!/usr/bin/env bash

# Function to display a banner or logo
function show_banner() {
  echo "
▗▄▄▄▖▗▖    ▗▄▖ ▗▖  ▗▖▗▄▄▄▖     ▗▄▖  ▗▄▄▖
▐▌   ▐▌   ▐▌ ▐▌▐▛▚▞▜▌▐▌       ▐▌ ▐▌▐▌   
▐▛▀▀▘▐▌   ▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘    ▐▌ ▐▌ ▝▀▚▖
▐▌   ▐▙▄▄▖▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖    ▝▚▄▞▘▗▄▄▞▘

"
  clear
}

function network_setup() {
    show_banner "Network and wifi Setup"
    echo "Launching networkmanager"
    if ping -c 1 1.1.1.1 &> /dev/null; then
        echo "1.1.1.1 is reachable. Skipping nmtui."
    else
        echo "1.1.1.1 is not reachable. Running nmtui."
        nmtui
    fi
    swww img ~/default.png
}

function select_graphics_driver() {
    show_banner "Graphics Driver Selection"
    
    local GRAPHICS_OPTIONS=$(cat <<EOF
1. Nvidia Open Source (nvidia-open-dkms)
2. Nvidia Proprietary (nvidia-dkms)
3. Nouveau Drivers (Open Source Nvidia)
4. Intel Open Source
5. AMD Open Source
6. All Open Source Drivers
7. VirtualBox Graphics
8. Back to Main Menu
EOF
)

    GRAPHICS_CHOICE=$(echo "$GRAPHICS_OPTIONS" | fzf --prompt="Select Graphics Driver: " \
        --height=40% --border --reverse)

    case "$GRAPHICS_CHOICE" in
        "1. Nvidia Open Source"*)
            GRAPHICS_PACKAGES="dkms libva-nvidia-driver nvidia-open-dkms xorg-server xorg-xinit"
            ;;
        "2. Nvidia Proprietary"*)
            GRAPHICS_PACKAGES="dkms libva-nvidia-driver nvidia nvidia-utils xorg-server xorg-xinit"
            ;;
        "3. Nouveau Drivers"*)
            GRAPHICS_PACKAGES="libva-mesa-driver mesa vulkan-nouveau xf86-video-nouveau xorg-server xorg-xinit"
            ;;
        "4. Intel Open Source"*)
            GRAPHICS_PACKAGES="intel-media-driver libva-intel-driver mesa vulkan-intel xorg-server xorg-xinit"
            ;;
        "5. AMD Open Source"*)
            GRAPHICS_PACKAGES="libva-mesa-driver mesa vulkan-radeon xf86-video-amdgpu xf86-video-ati xorg-server xorg-xinit"
            ;;
        "6. All Open Source Drivers"*)
            GRAPHICS_PACKAGES="intel-media-driver libva-intel-driver libva-mesa-driver mesa vulkan-intel vulkan-nouveau vulkan-radeon xf86-video-amdgpu xf86-video-ati xf86-video-nouveau xorg-server xorg-xinit"
            ;;
        "7. VirtualBox Graphics"*)
            GRAPHICS_PACKAGES="mesa xorg-server xorg-xinit"
            ;;
        "8. Back to Main Menu")
            return 1
            ;;
    esac
}

# Function to manage disks using cfdisk
function manage_disks() {
    show_banner "Disk Management - Use cfdisk to manage your disks"
    
    while true; do
        # Fetch available disks and partitions using lsblk
        # Fixed the awk command to properly handle disk size formatting
        DISKS=$(lsblk -d -o NAME,SIZE,TYPE | grep 'disk' | awk '{print $1 " (" $2 ")"}')\n

        # Show disks with fzf for selection, add "Back" option
        SELECTED_DISK=$(echo -e "$DISKS\nBack to Menu" | fzf --border \
            --prompt="Select a disk to manage or go back: " \
            --height=12 \
            --min-height=6 \
            --reverse \
            --border=rounded \
            --ansi)

        # If user selects 'Back' or nothing is selected
        if [[ -z "$SELECTED_DISK" ]] || [[ "$SELECTED_DISK" == "Back to Menu" ]]; then
            return
        fi

        # Extract disk name without the size
        SELECTED_DISK_NAME=$(echo "$SELECTED_DISK" | cut -d' ' -f1)
        
        if [[ -n "$SELECTED_DISK_NAME" ]]; then
            echo "Launching cfdisk for /dev/$SELECTED_DISK_NAME..."

            # Run cfdisk on the selected disk
            cfdisk "/dev/$SELECTED_DISK_NAME"

            # After quitting cfdisk, show message
            echo "You have exited cfdisk. Press any key to continue..."
            read -n 1
        fi
    done
}

function list_partitions() {
    local disk_line=$(lsblk -dnp -o NAME,SIZE | fzf --prompt="Select a disk: " --height=40% --border)
    if [[ -z "$disk_line" ]]; then
        echo "No disk selected. Going back..."
        return 1
    fi

    local disk=$(echo "$disk_line" | awk '{print $1}')
    local partitions=$(lsblk -Jnp "$disk" | jq -r '.blockdevices[0].children[]? | "\(.name) \(.size)"' | \
        fzf --prompt="Select a partition: " --height=40% --border)
    if [[ -z "$partitions" ]]; then
        echo "No partition selected. Going back..."
        return 1
    fi
    echo "$partitions"
}

function partition_menu() {
    while true; do
        show_banner "Partition Selection"
        local PART_OPTIONS=$(cat <<EOF
1. Select EFI Partition
2. Select Root Partition
3. Select Swap Partition
4. Select Home Partition
5. Back to Main Menu
EOF
)
        CHOICE=$(echo "$PART_OPTIONS" | fzf --prompt="Select an option: " \
            --height=40% --border --reverse)
            
        case "$CHOICE" in
            "1. Select EFI Partition")
                select_efi_partition
                ;;
            "2. Select Root Partition")
                select_root_partition
                ;;
            "3. Select Swap Partition")
                select_swap_partition
                ;;
            "4. Select Home Partition")
                select_home_partition
                ;;
            "5. Back to Main Menu")
                return
                ;;
        esac
    done
}

# Partition selection functions
function select_efi_partition() {
    show_banner "Select the EFI Partition"
    echo "Please select the EFI partition:"
    EFI=$(list_partitions)
    EFI="${EFI%% *}"
}

function select_swap_partition() {
    show_banner "Select the SWAP Partition"
    echo "Please select the SWAP partition:"
    SWAP=$(list_partitions)
    SWAP="${SWAP%% *}"
}

function select_root_partition() {
    show_banner "Select the Root Partition"
    echo "Please select the Root(/) partition:"
    ROOT=$(list_partitions)
    ROOT="${ROOT%% *}"
}

function select_home_partition() {
    show_banner "Select the Home Partition"
    echo "Please select the Home(/home) partition:"
    HOME=$(list_partitions)
    HOME="${HOME%% *}"
}

function user_configuration_menu() {
    show_banner "User Configuration"
    
    # Username
    echo "Enter username (leave empty to go back):"
    read -p "> " USERNAME
    [[ -z "$USERNAME" ]] && return

    # Password
    echo "Enter password for user $USERNAME:"
    read -s PASSWORD
    echo
    
    # Hostname
    echo "Enter hostname:"
    read -p "> " HOSTNAME
}

function system_configuration_menu() {
    while true; do
        show_banner "System Configuration"
        local SYS_OPTIONS=$(cat <<EOF
1. Select Timezone
2. Select Locale
3. Select Keyboard Layout
4. Select Desktop Environment
5. Back to Main Menu
EOF
)
        CHOICE=$(echo "$SYS_OPTIONS" | fzf --prompt="Select an option: " \
            --height=40% --border --reverse)
            
        case "$CHOICE" in
            "1. Select Timezone")
                select_timezone
                ;;
            "2. Select Locale")
                select_locale
                ;;
            "3. Select Keyboard Layout")
                select_keyboard_layout
                ;;
            "4. Select Desktop Environment")
                select_desktop_environment
                ;;
            "5. Back to Main Menu")
                return
                ;;
        esac
    done
}

function select_timezone() {
    show_banner "Timezone Selection"
    TIMEZONE=$(timedatectl list-timezones | fzf --prompt="Select Timezone: " --height=40% --border)
}

function select_locale() {
    show_banner "Locale Selection"
    LOCALE=$(cat /usr/share/i18n/SUPPORTED | cut -d' ' -f1 | fzf --prompt="Select Locale: " --height=40% --border)
}

function select_keyboard_layout() {
    show_banner "Keyboard Layout Selection"
    KEYBOARD=$(localectl list-keymaps | fzf --prompt="Select Keyboard Layout: " --height=40% --border)
}

function select_desktop_environment() {
    show_banner "Desktop Environment Selection"
    DESKTOP=$(echo -e "1. Hyprland\n2. KDE Plasma\n3. Gnome\n4. XFCE" | \
        fzf --prompt="Select Desktop Environment: " --height=40% --border)
}

function create_filesystems() {
    show_banner "Filesystem Creation"
    echo -e "\nCreating Filesystems...\n"
    
    # Confirm before formatting
    local CONFIRM=$(echo -e "Yes\nNo" | fzf --prompt="Are you sure you want to format the selected partitions? " \
        --height=40% --border)
    [[ "$CONFIRM" != "Yes" ]] && return 1

    mkfs.vfat -F32 -n "EFISYSTEM" "$EFI"
    mkswap "${SWAP}"
    swapon "${SWAP}"
    mkfs.ext4 -L "ROOT" "${ROOT}"
    
    HOME_RESET=$(echo -e "Yes\nNo" | fzf --prompt="Want to reset the home (${HOME}) partition? " --height=40% --border)
    if [[ "$HOME_RESET" == "Yes" ]]; then
        mkfs.ext4 -L "HOME" "${HOME}"
    fi
}

function mount_filesystems() {
    show_banner "Filesystem Mounting"
    echo -e "\nMounting Filesystems...\n"
    
    # Unmount if already mounted
    umount /mnt/boot 2>/dev/null
    umount /mnt/home 2>/dev/null
    umount /mnt 2>/dev/null
    
    # Mount partitions
    mount -t ext4 "${ROOT}" /mnt
    mkdir -p /mnt/boot
    mount -t vfat "${EFI}" /mnt/boot
    mkdir -p /mnt/home
    mount -t ext4 "${HOME}" /mnt/home
}

function install_system() {
    show_banner "Installing FlameOS"
    echo "Installing base system..."
    pacstrap /mnt base base-devel linux linux-firmware
    
    echo -e "\nInstalling dependencies..."
    pacstrap /mnt networkmanager grub efibootmgr os-prober dosfstools mtools \
        intel-ucode amd-ucode bluez bluez-utils blueman git $GRAPHICS_PACKAGES --noconfirm --needed

    echo "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
}

function configure_bootloader() {
    show_banner "Bootloader Installation"
    BIOS_VERSION=$(echo -e "New\nOld" | fzf --prompt="Your BIOS is old or new? " --height=40% --border)

    if [[ "$BIOS_VERSION" == "New" ]]; then
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="FlameOS"
    else
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id="FlameOS"
    fi
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

    
    arch-chroot /mnt mkdir -p /boot/grub/themes/shared
    arch-chroot /mnt cp -rf /etc/default/flameos.png /boot/grub/themes/shared/flameos.png 
}

function configure_system() {
    show_banner "System Configuration"
    echo -e "\nSetting up system...\n"
    
    # Copy setup files
    rsync -av --exclude='install.sh' --exclude='.git' --exclude='.gitignore' ./ /mnt/setup

    # Create configuration script
    cat <<REALEND > /mnt/setup/next.sh
#!/bin/bash
/setup/config.sh
useradd -m $USERNAME
usermod -aG wheel,audio,video,optical,storage,power $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "-----------------------"
echo "Setup Language and Keyboard"
echo "-----------------------"
sed -i "s/#en_US.UTF-8 UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

echo "$HOSTNAME" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOF

echo "-----------------------"
echo "Display and Audio Drivers"
echo "-----------------------"
pacman -S pipewire pipewire-pulse wireplumber --noconfirm --needed

systemctl enable NetworkManager
chown -R $USERNAME:$USERNAME /home/$USERNAME

if [[ "$DESKTOP" == "1. Hyprland" ]]; then
    /setup/hyprland.sh $USERNAME
elif [[ "$DESKTOP" == "2. KDE Plasma" ]]; then
    /setup/kde.sh $USERNAME
elif [[ "$DESKTOP" == "3. Gnome" ]]; then
    /setup/gnome.sh $USERNAME
elif [[ "$DESKTOP" == "4. XFCE" ]]; then
    /setup/xfce.sh $USERNAME
fi
REALEND
    chmod +x /mnt/setup/next.sh
    arch-chroot /mnt /setup/next.sh
    rm -rf /mnt/setup
}

function confirm_installation() {
    show_banner "Installation Confirmation"
    echo -e "\nConfiguration Summary:"
    echo "------------------------"
    echo "EFI Partition: $EFI"
    echo "Root Partition: $ROOT"
    echo "Swap Partition: $SWAP"
    echo "Home Partition: $HOME"
    echo "Username: $USERNAME"
    echo "Hostname: $HOSTNAME"
    echo "Timezone: $TIMEZONE"
    echo "Locale: $LOCALE"
    echo "Desktop: $DESKTOP"
    echo "Graphics: $GRAPHICS_CHOICE"
    echo "------------------------"
    
    local CONFIRM=$(echo -e "Yes\nNo" | fzf --prompt="Begin installation? " \
        --height=40% --border)
    [[ "$CONFIRM" == "Yes" ]]
}

function main_menu() {
    local OPTIONS
    while true; do
        show_banner "FlameOS Installer"
        
        OPTIONS=$(cat <<EOF
1. Network Setup
2. Manage Disks
3. Select Partitions
4. User Configuration
5. System Configuration
6. Select Graphics Driver
7. Begin Installation
8. Exit Installer
EOF
)
        
        CHOICE=$(echo "$OPTIONS" | fzf --prompt="Select an option: " \
            --height=40% --border --reverse)
            
        case "$CHOICE" in
            "1. Network Setup")
                network_setup
                ;;
            "2. Manage Disks")
                manage_disks
                ;;
            "3. Select Partitions")
                partition_menu
                ;;
            "4. User Configuration")
                user_configuration_menu
                ;;
            "5. System Configuration")
                system_configuration_menu
                ;;
            "6. Select Graphics Driver")
                select_graphics_driver
                ;;
            "7. Begin Installation")
                if confirm_installation; then
                    create_filesystems
                    mount_filesystems
                    install_system
                    configure_bootloader
                    configure_system

                    show_banner "Installation Complete"
                    local REBOOT=$(echo -e "Yes\nNo" | fzf --prompt="Do you want to reboot now? " \
                        --height=40% --border)
                    
                    [[ "$REBOOT" == "Yes" ]] && reboot
                fi
                ;;
            "8. Exit Installer")
                local CONFIRM=$(echo -e "Yes\nNo" | fzf --prompt="Are you sure you want to exit? " \
                    --height=40% --border)
                [[ "$CONFIRM" == "Yes" ]] && exit 0
                ;;
        esac
    done
}

# Start the installer
main_menu
