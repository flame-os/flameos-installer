#!/usr/bin/env bash

# FlameOS Installer - Partition Operations
# Auto partitioning, partition creation, and validation

# -------------------------
# Auto Partition - Erase Disk
# -------------------------
auto_partition_erase_disk() {
  show_banner "Auto Partition - Erase Disk"
  
  local all_disks
  all_disks=$(lsblk -d -o NAME,SIZE,MODEL | awk 'NR>1 && $1!~/loop/ {printf "/dev/%s\t%s\t%s\n", $1, $2, $3}')
  
  DISK=$(printf "%s\nCancel" "$all_disks" | eval "$FZF --prompt=\"Select disk to erase > \" --header=\"WARNING: This will erase ALL data on the selected disk\"") || return
  
  if [[ "$DISK" == "Cancel" || -z "$DISK" ]]; then
    return
  fi
  
  DISK=$(echo "$DISK" | awk '{print $1}')
  
  # Ask for partition options
  local want_swap
  want_swap=$(printf "Yes\nNo" | eval "$FZF --prompt=\"Create swap partition? > \" --header=\"Do you want a swap partition?\"") || return
  
  local want_home
  want_home=$(printf "Yes\nNo" | eval "$FZF --prompt=\"Create /home partition? > \" --header=\"Do you want a separate /home partition?\"") || return
  
  # Choose filesystem type
  local fs_type
  fs_type=$(printf "ext4 (Recommended)\nbtrfs\nxfs\nf2fs" | eval "$FZF --prompt=\"Root filesystem > \" --header=\"Choose filesystem for root partition\"") || return
  
  fs_type=$(echo "$fs_type" | awk '{print $1}')
  
  echo "Configuration:"
  echo "  Disk: $DISK"
  echo "  Filesystem: $fs_type"
  echo "  Swap: $want_swap"
  echo "  Separate /home: $want_home"
  echo
  echo "WARNING: This will DELETE ALL DATA on $DISK"
  read -rp "Type 'ERASE' to confirm: " confirm
  if [[ "$confirm" != "ERASE" ]]; then
    echo "Cancelled."
    read -rp "Press Enter to continue..."
    return
  fi
  
  # Wipe partition table
  wipefs -a "$DISK" 2>/dev/null || true
  
  # Calculate partition sizes
  local disk_size_gb=$(lsblk -d -o SIZE "$DISK" | tail -n1 | sed 's/[^0-9.]//g' | cut -d. -f1)
  local current_pos=1
  
  # Create partitions based on system type
  if [[ -d /sys/firmware/efi ]]; then
    # UEFI system
    parted "$DISK" mklabel gpt
    
    # EFI partition (512MB)
    parted "$DISK" mkpart primary fat32 ${current_pos}MiB 513MiB
    parted "$DISK" set 1 esp on
    current_pos=513
    
    PART_ASSIGN=()
    
    # Detect UEFI vs BIOS and create appropriate boot partition
    if [[ -d /sys/firmware/efi ]]; then
      # UEFI system - needs EFI System Partition
      PART_ASSIGN+=("${DISK}1:/boot/efi")
      log "UEFI system detected - creating /boot/efi partition"
      local part_num=2
    else
      # BIOS/Legacy system - create /boot partition
      parted "$DISK" mkpart primary ext4 ${current_pos}MiB $((current_pos + 1024))MiB
      current_pos=$((current_pos + 1024))
      PART_ASSIGN+=("${DISK}2:/boot")
      log "BIOS/Legacy system detected - creating /boot partition"
      local part_num=3
    fi
    
    # Swap partition if requested
    if [[ "$want_swap" == "Yes" ]]; then
      local swap_size=$((disk_size_gb > 40 ? 4 : disk_size_gb / 10))
      local swap_end=$((current_pos + swap_size * 1024))
      parted "$DISK" mkpart primary linux-swap ${current_pos}MiB ${swap_end}MiB
      PART_ASSIGN+=("${DISK}${part_num}:swap")
      current_pos=$swap_end
      ((part_num++))
    fi
    
    # Home partition if requested
    if [[ "$want_home" == "Yes" ]]; then
      local home_size=$((disk_size_gb / 2))  # Half remaining space
      local home_end=$((current_pos + home_size * 1024))
      parted "$DISK" mkpart primary "$fs_type" ${current_pos}MiB ${home_end}MiB
      PART_ASSIGN+=("${DISK}${part_num}:/home")
      current_pos=$home_end
      ((part_num++))
    fi
    
    # Root partition (rest of disk)
    parted "$DISK" mkpart primary "$fs_type" ${current_pos}MiB 100%
    PART_ASSIGN+=("${DISK}${part_num}:/")
    
  else
    # BIOS system
    parted "$DISK" mklabel msdos
    
    PART_ASSIGN=()
    local part_num=1
    
    # Swap partition if requested
    if [[ "$want_swap" == "Yes" ]]; then
      local swap_size=$((disk_size_gb > 40 ? 4 : disk_size_gb / 10))
      local swap_end=$((current_pos + swap_size * 1024))
      parted "$DISK" mkpart primary linux-swap ${current_pos}MiB ${swap_end}MiB
      PART_ASSIGN+=("${DISK}${part_num}:swap")
      current_pos=$swap_end
      ((part_num++))
    fi
    
    # Home partition if requested
    if [[ "$want_home" == "Yes" ]]; then
      local home_size=$((disk_size_gb / 2))  # Half remaining space
      local home_end=$((current_pos + home_size * 1024))
      parted "$DISK" mkpart primary "$fs_type" ${current_pos}MiB ${home_end}MiB
      PART_ASSIGN+=("${DISK}${part_num}:/home")
      current_pos=$home_end
      ((part_num++))
    fi
    
    # Root partition (rest of disk)
    parted "$DISK" mkpart primary "$fs_type" ${current_pos}MiB 100%
    PART_ASSIGN+=("${DISK}${part_num}:/")
  fi
  
  partprobe "$DISK" 2>/dev/null || true
  sleep 2
  
  echo "Auto partitioning complete with $fs_type filesystem!"
  echo "Created partitions:"
  for assignment in "${PART_ASSIGN[@]}"; do
    local part="${assignment%%:*}"
    local mount="${assignment#*:}"
    echo "  $part -> $mount"
  done
  
  read -rp "Press Enter to continue..."
}

# -------------------------
# Auto Partition - Existing Partition
# -------------------------
auto_partition_existing_partition() {
  show_banner "Auto Partition - Use Existing Partition"
  
  # Show all existing partitions from all disks
  local all_parts=""
  local all_disks
  all_disks=$(lsblk -d -o NAME | awk 'NR>1 && $1!~/loop/ {print "/dev/"$1}')
  
  for disk in $all_disks; do
    local parts
    parts=$(lsblk -lnp -o NAME,SIZE,FSTYPE "$disk" | awk '$1!~/^\/dev\/[a-z]+$/ && $1~/^\/dev\// {print $1 "  " $2 "  " ($3?$3:"unformatted")}')
    if [[ -n "$parts" ]]; then
      all_parts+="$parts\n"
    fi
  done
  
  if [[ -z "$all_parts" ]]; then
    echo "No existing partitions found."
    read -rp "Press Enter to continue..."
    return
  fi

  local selected_partition
  selected_partition=$(printf "%b%s" "$all_parts" "Cancel" | eval "$FZF --prompt=\"Select partition for root > \" --header=\"Choose existing partition to use as root (/)\"") || return
  
  if [[ "$selected_partition" == "Cancel" || -z "$selected_partition" ]]; then
    return
  fi

  local root_part=$(echo "$selected_partition" | awk '{print $1}')
  
  # Ask if they want to reformat
  local reformat
  reformat=$(printf "Yes (Erase data)\nNo (Keep data)" | eval "$FZF --prompt=\"Reformat partition? > \" --header=\"Do you want to reformat $root_part?\"") || return
  
  local fs_type="ext4"
  if [[ "$reformat" == "Yes (Erase data)" ]]; then
    fs_type=$(printf "ext4 (Recommended)\nbtrfs\nxfs\nf2fs" | eval "$FZF --prompt=\"Filesystem type > \" --header=\"Choose filesystem for $root_part\"") || return
    fs_type=$(echo "$fs_type" | awk '{print $1}')
    
    echo "WARNING: This will erase all data on $root_part"
    read -rp "Type 'FORMAT' to confirm: " confirm
    if [[ "$confirm" != "FORMAT" ]]; then
      echo "Cancelled."
      read -rp "Press Enter to continue..."
      return
    fi
    
    # Format the partition
    case "$fs_type" in
      "ext4") mkfs.ext4 -F "$root_part" ;;
      "btrfs") mkfs.btrfs -f "$root_part" ;;
      "xfs") mkfs.xfs -f "$root_part" ;;
      "f2fs") mkfs.f2fs -f "$root_part" ;;
    esac
  fi
  
  # Set up basic assignments
  PART_ASSIGN=()
  PART_ASSIGN+=("$root_part:/")
  
  # Check if EFI system and look for EFI partition
  if [[ -d /sys/firmware/efi ]]; then
    echo "UEFI system detected. Looking for EFI partition..."
    local efi_parts
    efi_parts=$(printf "%b" "$all_parts" | grep -i "fat32\|vfat" | head -n5)
    
    if [[ -n "$efi_parts" ]]; then
      local efi_part
      efi_part=$(printf "%s\nSkip (no /boot/efi)" "$efi_parts" | eval "$FZF --prompt=\"Select EFI partition > \" --header=\"Choose EFI partition for /boot/efi\"") || return
      
      if [[ "$efi_part" != "Skip (no /boot/efi)" && -n "$efi_part" ]]; then
        local efi_path=$(echo "$efi_part" | awk '{print $1}')
        PART_ASSIGN+=("$efi_path:/boot/efi")
      fi
    fi
    
    # Look for /boot partition
    echo "Looking for /boot partition..."
    local boot_parts
    boot_parts=$(printf "%b" "$all_parts" | grep -E "ext[234]|xfs|btrfs" | head -n10)
    
    if [[ -n "$boot_parts" ]]; then
      local boot_part
      boot_part=$(printf "%s\nSkip (no /boot)" "$boot_parts" | eval "$FZF --prompt=\"Select /boot partition > \" --header=\"Choose partition for /boot (recommended for UEFI)\"") || return
      
      if [[ "$boot_part" != "Skip (no /boot)" && -n "$boot_part" ]]; then
        local boot_path=$(echo "$boot_part" | awk '{print $1}')
        # Make sure it's not the same as root
        if [[ "$boot_path" != "$root_part" ]]; then
          PART_ASSIGN+=("$boot_path:/boot")
        fi
      fi
    fi
  fi
  
  echo "Auto partition setup complete!"
  echo "Assignments:"
  for assignment in "${PART_ASSIGN[@]}"; do
    local part="${assignment%%:*}"
    local mount="${assignment#*:}"
    echo "  $part -> $mount"
  done
  
  read -rp "Press Enter to continue..."
}

# -------------------------
# Partition Validation
# -------------------------
validate_partition_assignments() {
  # Check for required root partition
  local has_root=false
  for a in "${PART_ASSIGN[@]}"; do
    local m="${a#*:}"
    if [[ "$m" == "/" ]]; then
      has_root=true
      ROOT_PART="${a%%:*}"
    elif [[ "$m" == "/boot/efi" ]]; then
      EFI_PART="${a%%:*}"
    elif [[ "$m" == "swap" ]]; then
      SWAP_PART="${a%%:*}"
    elif [[ "$m" == "/home" ]]; then
      HOME_PART="${a%%:*}"
    fi
  done

  if ! $has_root; then
    echo "ERROR: You must assign a partition to / (root)"
    read -rp "Press Enter to continue..."
    return 1
  fi

  # Check for EFI system
  if [[ -d /sys/firmware/efi ]] && [[ -z "$EFI_PART" ]]; then
    echo "WARNING: UEFI system detected but no /boot/efi partition assigned."
    echo "You may need a /boot/efi partition for proper booting."
    local confirm
    confirm=$(printf "Continue anyway\nGo back to assign /boot/efi partition" | eval "$FZF --prompt=\"Warning > \" --header=\"UEFI boot partition missing\"") || return 1
    if [[ "$confirm" == "Go back to assign /boot/efi partition" ]]; then
      return 1
    fi
  fi

  echo "Partition assignments validated successfully!"
  echo "Root: ${ROOT_PART:-none}"
  echo "EFI: ${EFI_PART:-none}"
  echo "Swap: ${SWAP_PART:-none}"
  echo "Home: ${HOME_PART:-none}"
  read -rp "Press Enter to continue..."
  return 0
}
