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
      install_desktop_environment
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
  show_banner "Formatting & Mounting"
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
  show_banner "Installing base system (pacstrap)"
  log "Pacstrapping base system onto /mnt"
  
  # Essential packages for a working system
  local base_packages="base base-devel linux linux-firmware networkmanager grub efibootmgr dosfstools mtools"
  
  # Add graphics packages if selected
  if [[ -n "${GRAPHICS_PACKAGES:-}" ]]; then
    pacstrap /mnt $base_packages $GRAPHICS_PACKAGES --noconfirm --needed || {
      echo "Pacstrap failed! Retrying with basic packages..."
      pacstrap /mnt base linux linux-firmware grub --noconfirm --needed || {
        echo "Critical: Base system installation failed!"
        read -rp "Press Enter to continue anyway..."
      }
    }
  else
    pacstrap /mnt $base_packages --noconfirm --needed || {
      echo "Pacstrap failed! Retrying with basic packages..."
      pacstrap /mnt base linux linux-firmware grub --noconfirm --needed || {
        echo "Critical: Base system installation failed!"
        read -rp "Press Enter to continue anyway..."
      }
    }
  fi
  
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
  show_banner "Configuring system in chroot"
  
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
  show_banner "Installing bootloader"
  
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
# Desktop Environment Installation
# -------------------------
install_desktop_environment() {
  if [[ -z "${DESKTOP:-}" || "$DESKTOP" == "Minimal" ]]; then
    log "No desktop environment selected, skipping"
    return 0
  fi
  
  show_banner "Installing Desktop Environment: $DESKTOP"
  
  # Install desktop environment using consolidated function
  arch-chroot /mnt bash -c "
    source /tmp/installer-vars.sh
    $(declare -f install_desktop_by_name)
    $(declare -f log)
    install_desktop_by_name '$DESKTOP'
  "
  
  log "Desktop environment installation completed"
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
