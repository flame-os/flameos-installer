#!/usr/bin/env bash

# FlameOS Installer - Partition Operations
# Auto partitioning, partition creation, and validation

# -------------------------
# Auto Partition - Erase Disk
# -------------------------
auto_partition_erase_disk() {
  clear
  echo "╔══════════════════════════════════════════════════════════════════════════════╗"
  echo "║                            AUTOMATIC PARTITIONING                           ║"
  echo "╚══════════════════════════════════════════════════════════════════════════════╝"
  echo
  echo "⚠️  WARNING: This will INSTANTLY erase ALL data on the selected disk!"
  echo
  
  local all_disks
  all_disks=$(lsblk -d -o NAME,SIZE,MODEL | awk 'NR>1 && $1!~/loop/ {printf "/dev/%s\t%s\t%s\n", $1, $2, $3}')
  
  echo "Available disks:"
  echo "$all_disks" | while IFS=$'\t' read -r disk size model; do
    echo "  💾 $disk ($size) - $model"
  done
  echo
  
  DISK=$(printf "%s\n❌ Cancel" "$all_disks" | eval "$FZF --prompt=\"💾 Select Disk › \" --header=\"Choose disk to partition automatically\" --border --height=15") || return
  
  if [[ "$DISK" == "❌ Cancel" || -z "$DISK" ]]; then
    return
  fi
  
  DISK=$(echo "$DISK" | awk '{print $1}')
  
  clear
  echo "╔══════════════════════════════════════════════════════════════════════════════╗"
  echo "║                              BOOT CONFIGURATION                              ║"
  echo "╚══════════════════════════════════════════════════════════════════════════════╝"
  echo
  echo "Selected disk: $DISK"
  echo
  
  # Select boot type with better UI
  local boot_type
  boot_type=$(printf "🔧 EFI (UEFI) - Modern systems\n🔧 MBR (Legacy BIOS) - Older systems" | eval "$FZF --prompt=\"⚙️  Boot Type › \" --header=\"Select boot type for your system\" --border --height=10") || return
  boot_type=$(echo "$boot_type" | awk '{print $2" "$3}')
  
  # Ask for swap partition with better UI
  local want_swap
  want_swap=$(printf "✅ Yes - Create swap partition\n❌ No - Skip swap partition" | eval "$FZF --prompt=\"💾 Swap › \" --header=\"Do you want a swap partition for hibernation?\" --border --height=10") || return
  want_swap=$(echo "$want_swap" | awk '{print $1}')
  
  clear
  echo "╔══════════════════════════════════════════════════════════════════════════════╗"
  echo "║                           PARTITIONING IN PROGRESS                          ║"
  echo "╚══════════════════════════════════════════════════════════════════════════════╝"
  echo
  echo "🔧 Configuration:"
  echo "   Disk: $DISK"
  echo "   Boot: $boot_type"
  echo "   Swap: $want_swap"
  echo "   Filesystem: ext4"
  echo
  echo "🚀 Starting automatic partitioning..."
  sleep 1
  
  # Unmount any mounted partitions on this disk
  echo "📤 Unmounting partitions..."
  for partition in $(lsblk -lnp -o NAME "$DISK" | grep -E "${DISK}[0-9]+"); do
    if mountpoint -q "$partition" 2>/dev/null || grep -q "$partition" /proc/mounts; then
      echo "   Unmounting $partition..."
      umount "$partition" 2>/dev/null || true
    fi
  done
  
  # Wipe partition table
  echo "🧹 Wiping partition table..."
  wipefs -a "$DISK" 2>/dev/null || true
  dd if=/dev/zero of="$DISK" bs=1M count=10 2>/dev/null || true
  
  # Calculate partition sizes
  local disk_size_gb=$(lsblk -d -o SIZE "$DISK" | tail -n1 | sed 's/[^0-9.]//g' | cut -d. -f1)
  local current_pos=1
  
  # Create partitions automatically based on boot type
  PART_ASSIGN=()
  
  if [[ "$boot_type" == "EFI (UEFI)" ]]; then
    echo "📋 Creating GPT partition table..."
    parted "$DISK" mklabel gpt || { echo "❌ Failed to create GPT table"; return 1; }
    
    echo "🔧 Creating EFI boot partition (1GB)..."
    parted "$DISK" mkpart primary fat32 ${current_pos}MiB 1025MiB || { echo "❌ Failed to create EFI partition"; return 1; }
    parted "$DISK" set 1 esp on || { echo "❌ Failed to set ESP flag"; return 1; }
    current_pos=1025
    
    PART_ASSIGN+=("${DISK}1:/boot/efi")
    local part_num=2
  else
    echo "📋 Creating MBR partition table..."
    parted "$DISK" mklabel msdos || { echo "❌ Failed to create MBR table"; return 1; }
    
    echo "🔧 Creating boot partition (1GB)..."
    parted "$DISK" mkpart primary ext4 ${current_pos}MiB 1025MiB || { echo "❌ Failed to create boot partition"; return 1; }
    parted "$DISK" set 1 boot on || { echo "❌ Failed to set boot flag"; return 1; }
    current_pos=1025
    
    PART_ASSIGN+=("${DISK}1:/boot")
    local part_num=2
  fi
  
  # Swap partition (if requested)
  if [[ "$want_swap" == "✅" ]]; then
    echo "💾 Creating swap partition..."
    local swap_size=$((disk_size_gb > 40 ? 4 : disk_size_gb / 10))
    local swap_end=$((current_pos + swap_size * 1024))
    parted "$DISK" mkpart primary linux-swap ${current_pos}MiB ${swap_end}MiB || { echo "❌ Failed to create swap"; return 1; }
    PART_ASSIGN+=("${DISK}${part_num}:swap")
    current_pos=$swap_end
    ((part_num++))
  fi
  
  # Root partition (remaining space)
  echo "🏠 Creating root partition..."
  parted "$DISK" mkpart primary ext4 ${current_pos}MiB 100% || { echo "❌ Failed to create root partition"; return 1; }
  PART_ASSIGN+=("${DISK}${part_num}:/")
  
  # Wait for partitions to be recognized
  echo "⏳ Waiting for system to recognize partitions..."
  sleep 2
  partprobe "$DISK"
  sleep 1
  
  # Set partition variables for validation
  ROOT_PART="${DISK}${part_num}"
  if [[ "$boot_type" == "EFI (UEFI)" ]]; then
    EFI_PART="${DISK}1"
  fi
  if [[ "$want_swap" == "✅" ]]; then
    SWAP_PART="${DISK}$((part_num-1))"
  fi
  
  clear
  echo "╔══════════════════════════════════════════════════════════════════════════════╗"
  echo "║                          PARTITIONING COMPLETED!                            ║"
  echo "╚══════════════════════════════════════════════════════════════════════════════╝"
  echo
  echo "✅ Automatic partitioning completed successfully!"
  echo
  echo "📋 Created partitions:"
  for assignment in "${PART_ASSIGN[@]}"; do
    local part="${assignment%%:*}"
    local mount="${assignment#*:}"
    case "$mount" in
      "/") echo "   🏠 $part → $mount (Root filesystem)" ;;
      "/boot/efi") echo "   🔧 $part → $mount (EFI boot partition)" ;;
      "/boot") echo "   🔧 $part → $mount (Boot partition)" ;;
      "swap") echo "   💾 $part → $mount (Swap partition)" ;;
      *) echo "   📁 $part → $mount" ;;
    esac
  done
  echo
  echo "🎉 Your disk is now ready for FlameOS installation!"
  echo "   You can proceed to 'Continue Installation' from the main menu."
  
  log "Auto partitioning completed successfully"
  echo
  read -rp "Press Enter to return to main menu..."
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
    
    printf "Will erase %s. Type 'FORMAT' to confirm: " "$root_part"
    read -r confirm
    if [[ "$confirm" != "FORMAT" ]]; then
      echo "Cancelled."
      read -rp "Press Enter to continue..."
      return
    fi
    
    # Unmount partition if mounted
    if mountpoint -q "$root_part" 2>/dev/null || grep -q "$root_part" /proc/mounts; then
      echo "Unmounting $root_part..."
      umount "$root_part" 2>/dev/null || true
    fi
    
    # Format the partition
    case "$fs_type" in
      "ext4") mkfs.ext4 -F "$root_part" ;;
      "btrfs") mkfs.btrfs -f "$root_part" ;;
      "xfs") mkfs.xfs -f "$root_part" ;;
      "f2fs") mkfs.f2fs -f "$root_part" ;;
    esac
  fi
  
  # Set up automatic assignments - only root partition
  PART_ASSIGN=()
  PART_ASSIGN+=("$root_part:/")
  ROOT_PART="$root_part"
  
  echo "Auto partition setup complete!"
  echo "Using existing partition: $root_part -> /"
  echo
  echo "Note: Boot partition will be handled automatically during installation"
  
  read -rp "Press Enter to continue..."
}

# -------------------------
# Partition Validation
# -------------------------
validate_partition_assignments() {
  # Check for required root partition
  local has_root=false
  local has_boot=false
  
  for a in "${PART_ASSIGN[@]}"; do
    local m="${a#*:}"
    if [[ "$m" == "/" ]]; then
      has_root=true
      ROOT_PART="${a%%:*}"
    elif [[ "$m" == "/boot/efi" ]]; then
      EFI_PART="${a%%:*}"
      has_boot=true
    elif [[ "$m" == "/boot" ]]; then
      has_boot=true
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

  echo "✓ Partition assignments validated successfully!"
  echo "Current assignments:"
  for assignment in "${PART_ASSIGN[@]}"; do
    local part="${assignment%%:*}"
    local mount="${assignment#*:}"
    echo "  $part -> $mount"
  done
  echo
  echo "Root: ${ROOT_PART:-none}"
  echo "EFI: ${EFI_PART:-none}"
  echo "Swap: ${SWAP_PART:-none}"
  echo "Home: ${HOME_PART:-none}"
  read -rp "Press Enter to continue..."
  return 0
}
