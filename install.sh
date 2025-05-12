#!/usr/bin/env bash
sudo pacman -Sy pirewire wireplumber xdg-desktop-portal-hyprland
# Function to display a banner or logo
function show_banner() {
    clear
echo "
  █████▒██▓    ▄▄▄       ███▄ ▄███▓▓█████     ▒█████    ██████ 
▓██   ▒▓██▒   ▒████▄    ▓██▒▀█▀ ██▒▓█   ▀    ▒██▒  ██▒▒██    ▒ 
▒████ ░▒██░   ▒██  ▀█▄  ▓██    ▓██░▒███      ▒██░  ██▒░ ▓██▄   
░▓█▒  ░▒██░   ░██▄▄▄▄██ ▒██    ▒██ ▒▓█  ▄    ▒██   ██░  ▒   ██▒
░▒█░   ░██████▒▓█   ▓██▒▒██▒   ░██▒░▒████▒   ░ ████▓▒░▒██████▒▒
 ▒ ░   ░ ▒░▓  ░▒▒   ▓▒█░░ ▒░   ░  ░░░ ▒░ ░   ░ ▒░▒░▒░ ▒ ▒▓▒ ▒ ░
 ░     ░ ░ ▒  ░ ▒   ▒▒ ░░  ░      ░ ░ ░  ░     ░ ▒ ▒░ ░ ░▒  ░ ░
 ░ ░     ░ ░    ░   ▒   ░      ░      ░      ░ ░ ░ ▒  ░  ░  ░  
           ░  ░     ░  ░       ░      ░  ░       ░ ░        ░  
                                                              
" | lolcat
    echo -e "$1\n"
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

}

# Function to manage disks using cfdisk
function manage_disks() {
    show_banner "Disk Management - Use cfdisk to manage your disks"
    
    while true; do
        # Fetch available disks and partitions using lsblk
        DISKS=$(lsblk -d -o NAME,SIZE,TYPE | grep 'disk' | awk '{print $1 " ('$2')"}')

        # Show disks with fzf for selection, add "Next" option to skip
        SELECTED_DISK=$(echo -e "$DISKS\nNext" | fzf --border --prompt="Select a disk to manage or press 'Next' to skip: " \
            --height=12 --min-height=6 --reverse --border=rounded --ansi)

        # If user selects 'Next' or skips
        if [[ "$SELECTED_DISK" == "Next" ]]; then
            echo "Skipping disk setup."
            break
        fi

        # If a disk is selected, run cfdisk on that disk
        if [[ -n "$SELECTED_DISK" ]]; then
            SELECTED_DISK_NAME=$(echo "$SELECTED_DISK" | awk '{print $1}')
            echo "Launching cfdisk for /dev/$SELECTED_DISK_NAME..."

            # Run cfdisk on the selected disk
            cfdisk /dev/$SELECTED_DISK_NAME

            # After quitting cfdisk, show fzf menu again
            echo "You have exited cfdisk. You can select a new disk or skip."

        else
            # No disk selected, exit the loop
            echo "No disk selected. Exiting disk management."
            break
        fi
    done
}






# Function to list disks and partitions
function list_partitions() {
    # Step 1: Select a disk
    local disk_line=$(lsblk -dnp -o NAME,SIZE | fzf --prompt="Select a disk: " --height=40% --border)
    if [[ -z "$disk_line" ]]; then
        echo "No disk selected. Going back..."
        return 1
    fi

    # Extract just the disk path (first word in the line)
    local disk=$(echo "$disk_line" | awk '{print $1}')

    # Step 2: Get partitions under the selected disk
    local partitions=$(lsblk -Jnp "$disk" | jq -r '.blockdevices[0].children[]? | "\(.name) \(.size)"' | fzf --prompt="Select a partition: " --height=40% --border)
    if [[ -z "$partitions" ]]; then
        echo "No partition selected. Going back..."
        return 1
    fi
    echo "$partitions"
}

# Function to prompt and select EFI partition
function select_efi_partition() {
    show_banner "Select the EFI Partition"
    echo "Please select the EFI partition:"
    EFI=$(list_partitions)
    EFI="${EFI%% *}"
}

# Function to prompt and select SWAP partition
function select_swap_partition() {
    show_banner "Select the SWAP Partition"
    echo "Please select the SWAP partition:"
    SWAP=$(list_partitions)
    SWAP="${SWAP%% *}"
}

# Function to prompt and select ROOT partition
function select_root_partition() {
    show_banner "Select the Root Partition"
    echo "Please select the Root(/) partition:"
    ROOT=$(list_partitions)
    ROOT="${ROOT%% *}"
}

# Function to prompt and select HOME partition
function select_home_partition() {
    show_banner "Select the Home Partition"
    echo "Please select the Home(/home) partition:"
    HOME=$(list_partitions)
    HOME="${HOME%% *}"
}

# Function to prompt user for basic inputs
function user_inputs() {
    show_banner "User Configuration"

    # Suggest common usernames or allow manual entry
    echo "Choose a username (or type your own and press Enter):"
    read -p "Enter custom username: " USERNAME

    # Read password securely
    echo "Enter password for user $USERNAME:"
    read -s PASSWORD
    echo

    # Hostname suggestions
        read -p "Enter custom hostname: " HOSTNAME
}


# Function to select timezone
function select_timezone() {
    show_banner "Timezone Selection"
    echo "Please enter the timezone (example: America/New_York):"
    TIMEZONE=$(timedatectl list-timezones | fzf --prompt="Select Timezone: " --height=40% --border)
}

# Function to select locale
function select_locale() {
    show_banner "Locale Selection"
    echo "Please enter the locale (example: en_US.UTF-8):"
    LOCALE=$(cat /usr/share/i18n/SUPPORTED | cut -d' ' -f1 | fzf --prompt="Select Locale: " --height=40% --border)
}

# Function to select keyboard layout
function select_keyboard_layout() {
    show_banner "Keyboard Layout Selection"
    echo "Please enter the keyboard layout (example: us):"
    KEYBOARD=$(localectl list-keymaps | fzf --prompt="Select Keyboard Layout: " --height=40% --border)
}

# Function to select desktop environment
function select_desktop_environment() {
    show_banner "Desktop Environment Selection"
    echo "Please enter Your Desktop Environment:"
    DESKTOP=$(echo -e "1. Hyprland\n2. KDE Plasma\n3. Gnome\n4. XFCE" | fzf --prompt="Select Desktop Environment: " --height=40% --border)
}

function create_filesystems() {
    show_banner "Filesystem Creation"
    echo -e "\nCreating Filesystems...\n"
    mkfs.vfat -F32 -n "EFISYSTEM" "$EFI"
    mkswap "${SWAP}"
    swapon "${SWAP}"
    mkfs.ext4 -L "ROOT" "${ROOT}"
        HOME_RESET=$(echo -e "Yes\nNo" | fzf --prompt="Want to reset the home (${HOME}) pertition ?: " --height=40% --border)
    if [[ "$DESKTOP" == "Yes" ]]; then
     mkfs.ext4 -L "HOME" "${HOME}"
    fi
    echo -e "\n Skipping reset of ${HOME}"
}

# Function to create and mount filesystems
function mount_filesystems() {
    show_banner "Filesystem Mounting"
    echo -e "\nMounting Filesystems...\n"
    umount /mnt
    umount /mnt/boot
    umount /mnt/home
    mount -t ext4 "${ROOT}" /mnt
    mkdir -p /mnt/boot
    mount -t vfat "${EFI}" /mnt/boot
    mkdir -p /mnt/home
    mount -t ext4 "${HOME}" /mnt/home
}

# Function to install the base system
function install_system() {
    show_banner "Installing FlameOS"
    echo "Installing FlameOS..."
    pacstrap /mnt base base-devel linux linux-firmware
 
    echo -e "\nSetup Dependencies...\n"
    pacstrap /mnt networkmanager grub efibootmgr os-prober dosfstools mtools intel-ucode amd-ucode bluez bluez-utils blueman git --noconfirm --needed

    genfstab -U /mnt >> /mnt/etc/fstab
}

# Function to install and configure bootloader
function configure_bootloader() {
    show_banner "Bootloader Installation"
    echo -e "Bootloader Installation...\n"
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id="FlameOS"
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

# Function to configure the system
function configure_system() {
    show_banner "System Configuration"
    echo -e "\nSetting up system...\n"
rsync -av --exclude='install.sh' --exclude='.git' --exclude='.gitignore' ./ /mnt/setup
    cat <<REALEND > /mnt/setup/next.sh
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
pacman -S pipewire pipewire-pulse wireplumber  --noconfirm --needed

systemctl enable NetworkManager
# Desktop Environment
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
    arch-chroot /mnt sh setup/next.sh
sudo rm -rf /mnt/setup
}

# Main function to execute all steps in order
function main() {
    show_banner ""
    manage_disks
    select_efi_partition
    select_swap_partition
    select_root_partition
    select_home_partition
    user_inputs
    select_timezone
    select_locale
    select_keyboard_layout
    select_desktop_environment

    show_banner "Confirmation"
    echo "You are about to start the installation process. Once started, you cannot go back."
    echo "Press [Enter] to continue or [Ctrl+C] to cancel."
    read

    create_filesystems
    mount_filesystems
    install_system
    configure_bootloader
    configure_system


    show_banner "Installation Complete"
    echo "FlameOS has been successfully installed!"
}

# Run the main function
main

