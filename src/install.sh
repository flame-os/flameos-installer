#!/usr/bin/env bash

# FlameOS Installer - System Installation
# Base system installation and bootloader setup

# -------------------------
# Summary and Install Flow
# -------------------------
summary_and_install_flow() {
  show_banner "Summary"
  echo "Selections:"
  echo " Partition Assignments:"
  if [[ ${#PART_ASSIGN[@]} -gt 0 ]]; then
    for assignment in "${PART_ASSIGN[@]}"; do
      local part="${assignment%%:*}"
      local mount="${assignment#*:}"
      echo "   $part -> $mount"
    done
  else
    echo "   No partitions assigned"
  fi
  echo " User: ${USERNAME:-not set}"
  echo " Hostname: ${HOSTNAME:-not set}"
  echo " Timezone: ${TIMEZONE:-not set}"
  echo " Locale: ${LOCALE:-not set}"
  echo " Desktop: ${DESKTOP:-not set}"
  echo " Graphics packages: ${GRAPHICS_PACKAGES:-none}"
  if [[ -n "${ADDITIONAL_PACKAGES:-}" ]]; then
    local pkg_count=$(echo "$ADDITIONAL_PACKAGES" | wc -l)
    echo " Additional packages: $pkg_count selected"
  else
    echo " Additional packages: none"
  fi
  echo
  
  local act
  act=$(printf "Install now\nGo Back to main menu\nExit installer\n" | eval "$FZF --prompt=\"Action > \" --header=\"Choose action\"") || act=""
  case "$act" in
    "Install now")
      log "Beginning actual installation"
      # Validate and set partition variables
      if ! validate_partition_assignments; then
        echo "Partition validation failed!"
        read -rp "Press Enter to continue..."
        return 1
      fi
      format_and_mount_all || { log "Format and mount failed"; return 1; }
      install_base_system
      write_chroot_script_and_run
      install_bootloader
      configure_flameos_system
      install_desktop_environment
      install_audio_system
      log "Installation sequence finished."
      show_completion_screen
      return 0
      ;;
    "Go Back to main menu")
      return 1
      ;;
    "Exit installer")
      exit 0
      ;;
    *)
      return 1
      ;;
  esac
}

# -------------------------
# Format and Mount
# -------------------------
format_and_mount_all() {
  show_banner "Installing System - Formatting & Mounting"
  log "Starting format/mount with assignments: ${PART_ASSIGN[*]}"
  
  if [[ -z "${ROOT_PART:-}" ]]; then
    echo "No root partition selected. Aborting format/mount."
    return 1
  fi

  # Unmount any /mnt leftovers
  umount -R /mnt 2>/dev/null || true
  
  # Format partitions based on assigned mountpoints
  for a in "${PART_ASSIGN[@]}"; do
    local p="${a%%:*}"
    local m="${a#*:}"
    case "$m" in
      "/" )
        log "Formatting root $p as ext4"
        mkfs.ext4 -F -L ROOT "$p"
        ;;
      "/boot/efi" )
        log "Formatting EFI $p as vfat"
        mkfs.vfat -F32 -n EFISYSTEM "$p"
        ;;
      "/boot" )
        log "Formatting boot $p as ext4"
        mkfs.ext4 -F -L BOOT "$p"
        ;;
      "/home" )
        log "Formatting home $p as ext4"
        mkfs.ext4 -F -L HOME "$p"
        ;;
      "swap" )
        log "Setting up swap on $p"
        mkswap -L SWAP "$p"
        swapon "$p"
        ;;
    esac
  done

  # Mount root first
  mount "$ROOT_PART" /mnt
  
  # Create and mount others
  mkdir -p /mnt/boot /mnt/boot/efi /mnt/home
  for a in "${PART_ASSIGN[@]}"; do
    local p="${a%%:*}"
    local m="${a#*:}"
    case "$m" in
      "/boot/efi" )
        mount "$p" /mnt/boot/efi 2>/dev/null || true
        ;;
      "/boot" )
        mount "$p" /mnt/boot 2>/dev/null || true
        ;;
      "/home" )
        mount "$p" /mnt/home 2>/dev/null || true
        ;;
    esac
  done
  
  log "All partitions formatted and mounted."
  return 0
}

# -------------------------
# Base System Installation
# -------------------------
install_base_system() {
  show_banner "Installing System - Base Packages"
  log "Pacstrapping base system onto /mnt"
  
  # Essential packages for a working system
  local base_packages="base base-devel linux linux-firmware networkmanager grub efibootmgr dosfstools mtools"
  
  # Add graphics packages if selected
  local all_packages="$base_packages"
  if [[ -n "${GRAPHICS_PACKAGES:-}" ]]; then
    all_packages="$all_packages $GRAPHICS_PACKAGES"
  fi
  
  # Add additional packages if selected
  if [[ -n "${ADDITIONAL_PACKAGES:-}" ]]; then
    local additional_list=$(echo "$ADDITIONAL_PACKAGES" | tr '\n' ' ')
    all_packages="$all_packages $additional_list"
    log "Including additional packages: $additional_list"
  fi
  
  # Install all packages
  pacstrap /mnt $all_packages --noconfirm --needed || {
    echo "Pacstrap failed! Retrying with basic packages..."
    pacstrap /mnt base linux linux-firmware grub --noconfirm --needed || {
      echo "Critical: Base system installation failed!"
      read -rp "Press Enter to continue anyway..."
    }
  }
  
  # Generate fstab
  genfstab -U /mnt >> /mnt/etc/fstab || {
    echo "Warning: fstab generation failed"
  }
  
  log "Base system installed and fstab generated."
}

# -------------------------
# Chroot Configuration
# -------------------------
write_chroot_script_and_run() {
  show_banner "Configuring System"
  
  cat > /mnt/setup_next.sh <<CHROOT
#!/usr/bin/env bash
set -euo pipefail

# Set timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE:-UTC} /etc/localtime
hwclock --systohc

# Set locale
echo "${LOCALE:-en_US.UTF-8} UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=${LOCALE:-en_US.UTF-8}" > /etc/locale.conf

# Set hostname
echo "${HOSTNAME:-flameos}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME:-flameos}.localdomain ${HOSTNAME:-flameos}
EOF

# Create user
useradd -m -G wheel,audio,video,optical,storage -s /bin/bash "${USERNAME:-user}"
echo "${USERNAME:-user}:${PASSWORD:-password}" | chpasswd
echo "root:${PASSWORD:-password}" | chpasswd

# Enable sudo for wheel group
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Enable NetworkManager
systemctl enable NetworkManager

echo "Chroot configuration complete"
CHROOT

  chmod +x /mnt/setup_next.sh
  arch-chroot /mnt /setup_next.sh || {
    echo "Chroot configuration failed!"
    read -rp "Press Enter to continue..."
  }
  rm -f /mnt/setup_next.sh
}

# -------------------------
# Bootloader Installation
# -------------------------
install_bootloader() {
  show_banner "Installing Bootloader"
  
  # Ensure grub is installed in chroot
  arch-chroot /mnt pacman -S --noconfirm grub efibootmgr dosfstools mtools || {
    echo "Failed to install grub packages"
    read -rp "Press Enter to continue anyway..."
  }
  
  # Decide UEFI vs BIOS
  if [[ -d /sys/firmware/efi ]]; then
    log "System booted in UEFI mode"
    
    if [[ -n "${EFI_PART:-}" ]]; then
      # Ensure EFI partition is mounted
      mkdir -p /mnt/boot/efi
      mount "$EFI_PART" /mnt/boot/efi 2>/dev/null || {
        echo "Warning: Could not mount EFI partition $EFI_PART"
      }
      
      # Install GRUB for UEFI
      arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="FlameOS" --recheck || {
        echo "GRUB UEFI installation failed!"
        read -rp "Press Enter to continue..."
      }
      
      # Generate GRUB config
      arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || {
        echo "GRUB config generation failed!"
        read -rp "Press Enter to continue..."
      }
      
      log "GRUB installed for UEFI."
    else
      echo "ERROR: No EFI partition assigned for UEFI system!"
      read -rp "Press Enter to continue..."
    fi
  else
    log "System booted in BIOS/Legacy mode"
    
    # Find the disk containing root partition
    local root_disk=""
    if [[ -n "${ROOT_PART:-}" ]]; then
      root_disk=$(echo "$ROOT_PART" | sed 's/[0-9]*$//')
    else
      root_disk="/dev/sda"  # fallback
    fi
    
    # Install GRUB for BIOS
    arch-chroot /mnt grub-install --target=i386-pc "$root_disk" --recheck || {
      echo "GRUB BIOS installation failed!"
      read -rp "Press Enter to continue..."
    }
    
    # Generate GRUB config
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || {
      echo "GRUB config generation failed!"
      read -rp "Press Enter to continue..."
    }
    
    log "GRUB installed for BIOS."
  fi
}

# -------------------------
# Additional Packages Selection
# -------------------------
select_additional_packages() {
  show_banner "Additional Packages Selection"
  
  echo "Fetching available packages from repositories..."
  
  # Get all available packages from core, extra, and flameos-core repos
  local all_packages=$(pacman -Sl core extra 2>/dev/null | awk '{print $2}' | sort -u)
  
  # Add flameos-core packages if available
  local flameos_packages=$(pacman -Sl flameos-core 2>/dev/null | awk '{print $2}' | sort -u || true)
  
  # Combine all packages
  local combined_packages=$(echo -e "$all_packages\n$flameos_packages" | sort -u | grep -v '^$')
  
  if [[ -z "$combined_packages" ]]; then
    echo "No packages found. Make sure you have internet connection."
    read -rp "Press Enter to continue..."
    return 1
  fi
  
  echo "Select additional packages to install (use TAB for multi-select, ENTER to confirm):"
  echo "Press ESC or Ctrl+C to skip package selection"
  echo
  
  # Use fzf for multi-select package selection
  local selected_packages
  selected_packages=$(echo "$combined_packages" | eval "$FZF --multi --prompt=\"Select packages > \" --header=\"TAB: select/deselect, ENTER: confirm selection\"") || {
    echo "No additional packages selected."
    ADDITIONAL_PACKAGES=""
    return 0
  }
  
  if [[ -n "$selected_packages" ]]; then
    ADDITIONAL_PACKAGES="$selected_packages"
    local count=$(echo "$selected_packages" | wc -l)
    echo
    echo "Selected $count additional packages:"
    echo "$selected_packages" | sed 's/^/  - /'
    echo
    
    local confirm
    confirm=$(printf "Confirm selection\nReselect packages\nSkip additional packages" | eval "$FZF --prompt=\"Action > \" --header=\"Confirm your package selection\"") || confirm="Skip additional packages"
    
    case "$confirm" in
      "Confirm selection")
        log "Additional packages selected: $(echo "$selected_packages" | tr '\n' ' ')"
        return 0
        ;;
      "Reselect packages")
        select_additional_packages
        return $?
        ;;
      "Skip additional packages")
        ADDITIONAL_PACKAGES=""
        return 0
        ;;
    esac
  else
    ADDITIONAL_PACKAGES=""
    echo "No additional packages selected."
  fi
}

# -------------------------
# FlameOS System Configuration
# -------------------------
configure_flameos_system() {
  show_banner "Configuring FlameOS System"
  
  arch-chroot /mnt bash -c '
    # Install reflector
    pacman -S --noconfirm reflector
    
    # Create os-release
    cat > /etc/os-release <<EOF
NAME="FlameOS"
PRETTY_NAME="FlameOS"
ID=flameos
BUILD_ID=rolling
ANSI_COLOR="38;2;220;50;47"
HOME_URL="https://github.com/flame-os"
SUPPORT_URL="https://github.com/flame-os"
BUG_REPORT_URL="https://github.com/flame-os"
LOGO=flameos
IMAGE_ID=flameos
IMAGE_VERSION=2025.05.11
EOF
    
    # Add FlameOS repository
    if ! grep -q "\[flameos-core\]" /etc/pacman.conf; then
      cat >> /etc/pacman.conf <<EOF

[flameos-core]
SigLevel = Optional DatabaseOptional
Server = https://flame-os.github.io/core/\$arch
EOF
    fi
    
    # Configure GRUB theme script
    cat > /etc/grub.d/05_debian_theme <<EOF
#!/bin/bash

SHARED_LOGO="/boot/grub/themes/shared/flameos.png"

if [[ ! -f "\$SHARED_LOGO" ]]; then
    echo "Shared logo not found at \$SHARED_LOGO"
    exit 1
fi

for theme_dir in /boot/grub/themes/*/; do
    [[ "\$theme_dir" == *"/shared/" ]] && continue
    mkdir -p "\${theme_dir}icons"
    cp "\$SHARED_LOGO" "\${theme_dir}icons/flameos.png"
done

echo "Logo copied to all GRUB themes."
EOF
    
    chmod +x /etc/grub.d/05_debian_theme
    
    # Update GRUB branding
    sed -i "s/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR=\"FlameOS\"/" /etc/default/grub || \
      echo "GRUB_DISTRIBUTOR=\"FlameOS\"" >> /etc/default/grub
    
    # Regenerate GRUB config
    grub-mkconfig -o /boot/grub/grub.cfg
  '
  
  log "FlameOS system configuration completed"
}

# -------------------------
# Desktop Environment Installation
# -------------------------
install_desktop_environment() {
  if [[ -z "${DESKTOP:-}" || "$DESKTOP" == "Minimal" ]]; then
    log "No desktop environment selected, skipping"
    return 0
  fi
  
  show_banner "Installing Desktop Environment: $DESKTOP"
  
  case "$DESKTOP" in
    "Hyprland")
      arch-chroot /mnt bash -c "
        pacman -S --noconfirm hyprland waybar wofi dunst kitty thunar firefox grim slurp wl-clipboard brightnessctl pamixer polkit-gnome xdg-desktop-portal-hyprland xdg-desktop-portal-wlr
        
        mkdir -p /home/${USERNAME}/.config/hypr
        cat > /home/${USERNAME}/.config/hypr/hyprland.conf <<'EOF'
monitor=,preferred,auto,auto
exec-once = waybar
exec-once = dunst
input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
}
general {
    gaps_in = 5
    gaps_out = 20
    border_size = 2
    col.active_border = rgba(33ccffee)
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}
bind = SUPER, Q, exec, kitty
bind = SUPER, C, killactive,
bind = SUPER, E, exec, thunar
bind = SUPER, R, exec, wofi --show drun
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
EOF
        chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config
      "
      ;;
    "KDE Plasma")
      arch-chroot /mnt pacman -S --noconfirm plasma-meta kde-applications sddm
      arch-chroot /mnt systemctl enable sddm
      ;;
    "GNOME")
      arch-chroot /mnt pacman -S --noconfirm gnome gnome-extra gdm
      arch-chroot /mnt systemctl enable gdm
      ;;
    "XFCE")
      arch-chroot /mnt pacman -S --noconfirm xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
      arch-chroot /mnt systemctl enable lightdm
      ;;
    "i3")
      arch-chroot /mnt pacman -S --noconfirm i3-wm i3status dmenu i3lock xorg-server lightdm
      arch-chroot /mnt systemctl enable lightdm
      ;;
    "Sway")
      arch-chroot /mnt pacman -S --noconfirm sway waybar wofi
      ;;
  esac
  
  log "Desktop environment installation completed"
}

# -------------------------
# Audio System Installation
# -------------------------
install_audio_system() {
  if [[ -z "${AUDIO_DRIVER:-}" ]]; then
    AUDIO_DRIVER="PulseAudio (Default)"
  fi
  
  show_banner "Installing Audio System: $AUDIO_DRIVER"
  log "Installing audio system: $AUDIO_DRIVER"
  
  local audio_packages
  audio_packages=$(get_audio_packages "$AUDIO_DRIVER")
  
  if [[ -n "$audio_packages" ]]; then
    arch-chroot /mnt bash -c "
      source /tmp/installer-vars.sh
      pacman -S --noconfirm $audio_packages
      
      # Enable audio services
      if [[ '$AUDIO_DRIVER' == *'PipeWire'* ]]; then
        systemctl --user enable pipewire pipewire-pulse wireplumber
      fi
    "
    log "Audio system installation completed"
  else
    log "No audio packages to install"
  fi
}

# -------------------------
# Completion Screen
# -------------------------
show_completion_screen() {
  show_banner "Installation Complete!"
  
  echo "FlameOS has been successfully installed!"
  echo
  echo "System Information:"
  echo " • User: $USERNAME"
  echo " • Hostname: $HOSTNAME"
  echo " • Desktop: ${DESKTOP:-Minimal}"
  echo " • Root partition: $ROOT_PART"
  if [[ -n "${EFI_PART:-}" ]]; then
    echo " • EFI partition: $EFI_PART"
  fi
  echo
  echo "You can now reboot into your new FlameOS system."
  echo
  
  local choice
  choice=$(printf "Reboot Now\nReturn to Main Menu\nExit Installer" | eval "$FZF --prompt=\"Next Action > \" --header=\"Installation completed successfully\"") || choice="Exit Installer"
  
  case "$choice" in
    "Reboot Now")
      echo "Rebooting in 3 seconds..."
      sleep 3
      reboot
      ;;
    "Return to Main Menu")
      return 0
      ;;
    "Exit Installer")
      exit 0
      ;;
  esac
}
