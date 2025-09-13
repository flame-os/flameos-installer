#!/usr/bin/env bash

# FlameOS Installer - Disk Management
# Disk selection and management functions

# -------------------------
# Main Disk Selection
# -------------------------
select_disk_step() {
  show_banner "Step: Installation Type"
  
  while true; do
    local display="=== Current Mount Points ===\n"
    if [[ ${#PART_ASSIGN[@]} -gt 0 ]]; then
      for assignment in "${PART_ASSIGN[@]}"; do
        local part="${assignment%%:*}"
        local mount="${assignment#*:}"
        display+="$part -> $mount\n"
      done
    else
      display+="No mount points assigned\n"
    fi
    
    display+="\n=== Installation Options ===\n"
    display+="Auto Partition\n"
    display+="Manual Partition Management\n"
    display+="\n=== Continue ===\n"
    display+="Continue Installation\n"
    display+="Go Back\n"
    
    local choice
    choice=$(printf "%b" "$display" | eval "$FZF --prompt=\"Installation Type > \" --header=\"Choose installation method\" --ansi") || choice=""
    
    if [[ -z "$choice" ]]; then
      return 1
    fi
    
    case "$choice" in
      "Auto Partition")
        auto_partition_menu
        ;;
      "Manual Partition Management")
        manual_partition_management
        ;;
      "Continue Installation")
        if [[ ${#PART_ASSIGN[@]} -eq 0 ]]; then
          echo "You must assign at least one mount point!"
          read -rp "Press Enter to continue..."
          continue
        fi
        # Validate and set partition variables
        if ! validate_partition_assignments; then
          echo "Partition validation failed!"
          read -rp "Press Enter to continue..."
          continue
        fi
        return 0
        ;;
      "Go Back")
        return 1
        ;;
    esac
  done
}

# -------------------------
# Auto Partition Menu
# -------------------------
auto_partition_menu() {
  show_banner "Auto Partition"
  
  local choice
  choice=$(printf "Erase Whole Disk\nUse Specific Partition\nGo Back" | eval "$FZF --prompt=\"Auto Partition > \" --header=\"Choose partitioning method\"") || return
  
  case "$choice" in
    "Erase Whole Disk")
      auto_partition_erase_disk
      ;;
    "Use Specific Partition")
      auto_partition_existing_partition
      ;;
    "Go Back")
      return
      ;;
  esac
}

# -------------------------
# Manual Partition Management
# -------------------------
manual_partition_management() {
  show_banner "Manual Partition Management"
  
  while true; do
    local display="=== Current Mount Points ===\n"
    if [[ ${#PART_ASSIGN[@]} -gt 0 ]]; then
      for assignment in "${PART_ASSIGN[@]}"; do
        local part="${assignment%%:*}"
        local mount="${assignment#*:}"
        display+="$part -> $mount\n"
      done
    else
      display+="No mount points assigned\n"
    fi
    
    display+="\n=== Available Disks ===\n"
    
    local all_disks
    all_disks=$(lsblk -d -o NAME | awk 'NR>1 && $1!~/loop/ {print "/dev/"$1}')
    
    for disk in $all_disks; do
      local disk_info
      disk_info=$(lsblk -d -o SIZE,MODEL "$disk" | tail -n1)
      display+="$disk  $disk_info\n"
    done
    
    display+="\n=== Actions ===\n"
    display+="Go Back to Installation Type\n"
    
    local choice
    choice=$(printf "%b" "$display" | eval "$FZF --prompt=\"Manual Management > \" --header=\"Select disk to manage or go back\" --ansi") || choice=""
    
    if [[ -z "$choice" ]]; then
      return
    fi
    
    # Check if user selected a disk
    if [[ "$choice" =~ ^(/dev/[a-z0-9n]+)[[:space:]] ]]; then
      local diskpath=$(echo "$choice" | awk '{print $1}')
      DISK="$diskpath"
      manage_single_disk
      continue
    fi
    
    case "$choice" in
      "Go Back to Installation Type")
        return
        ;;
    esac
  done
}

# -------------------------
# Single Disk Management
# -------------------------
manage_single_disk() {
  while true; do
    show_banner "Manage Disk: $DISK"
    
    local parts
    parts=$(lsblk -lnp -o NAME,SIZE,FSTYPE "$DISK" | awk '$1!~/^\/dev\/[a-z]+$/ && $1~/^\/dev\// {print $1"\t"$2"\t"($3?$3:"unformatted")}')

    local display="=== Partitions on $DISK ===\n"
    
    if [[ -n "$parts" ]]; then
      IFS=$'\n'
      for p in $parts; do
        local ppath=$(echo "$p" | awk '{print $1}')
        local psize=$(echo "$p" | awk '{print $2}')
        local pfs=$(echo "$p" | awk '{print $3}')
        local assigned="(unassigned)"
        for a in "${PART_ASSIGN[@]}"; do
          if [[ "${a%%:*}" == "$ppath" ]]; then
            assigned="-> ${a#*:}"
            break
          fi
        done
        display+="$ppath  $psize  $pfs  $assigned\n"
      done
      unset IFS
    else
      display+="No partitions found\n"
    fi

    display+="\n=== Actions ===\n"
    display+="Create New Partition\n"
    display+="Delete All Partitions\n"
    display+="Open Partition Editor (cfdisk)\n"
    display+="Go Back\n"

    local choice
    choice=$(printf "%b" "$display" | eval "$FZF --prompt=\"Manage $DISK > \" --header=\"Select partition or action\" --ansi") || choice=""

    if [[ -z "$choice" ]]; then
      break
    fi

    if [[ "$choice" =~ ^/dev/ ]]; then
      local partpath=$(echo "$choice" | awk '{print $1}')
      partition_action_menu "$partpath"
      continue
    fi

    case "$choice" in
      "Create New Partition")
        create_partition_interactive
        ;;
      "Delete All Partitions")
        delete_all_partitions
        ;;
      "Open Partition Editor (cfdisk)")
        echo "Opening cfdisk for $DISK..."
        cfdisk "$DISK" || true
        show_banner "Manage Disk: $DISK"
        echo "Returned from cfdisk. Press Enter to continue..."
        read -r
        ;;
      "Go Back")
        break
        ;;
    esac
  done
}

# -------------------------
# Partition Action Menu
# -------------------------
partition_action_menu() {
  local partpath="$1"
  
  local choice
  choice=$(printf "Assign Mount Point\nFormat Partition\nDelete Partition\nGo Back" | eval "$FZF --prompt=\"$partpath > \" --header=\"Choose action for partition\"") || return
  
  case "$choice" in
    "Assign Mount Point")
      assign_mount_point "$partpath"
      ;;
    "Format Partition")
      format_partition_interactive "$partpath"
      ;;
    "Delete Partition")
      delete_specific_partition "$partpath"
      ;;
    "Go Back")
      return
      ;;
  esac
}

# -------------------------
# Assign Mount Point
# -------------------------
assign_mount_point() {
  local partpath="$1"
  local mp
  mp=$(printf "/ (root)\n/boot/efi (EFI)\n/boot (boot)\n/home\nswap\nCustom mount point" | eval "$FZF --prompt=\"Mount point for $partpath > \" --header=\"Select mount point\"") || return
  
  case "$mp" in
    "/ (root)") mp="/" ;;
    "/boot/efi (EFI)") mp="/boot/efi" ;;
    "/boot (boot)") mp="/boot" ;;
    "/home") mp="/home" ;;
    "swap") mp="swap" ;;
    "Custom mount point")
      read -rp "Enter custom mount point: " mp
      if [[ -z "$mp" ]]; then
        echo "No mount point entered"
        return
      fi
      ;;
  esac
  
  # Remove existing assignment for this partition
  remove_partition_assignment "$partpath"
  
  # Remove existing assignment for this mount point
  local new_assignments=()
  for assignment in "${PART_ASSIGN[@]}"; do
    local existing_mount="${assignment#*:}"
    if [[ "$existing_mount" != "$mp" ]]; then
      new_assignments+=("$assignment")
    fi
  done
  PART_ASSIGN=("${new_assignments[@]}")
  
  # Add new assignment
  PART_ASSIGN+=("$partpath:$mp")
  
  # Auto-format boot partitions
  if [[ "$mp" == "/boot/efi" ]]; then
    echo "Auto-formatting $partpath as FAT32 for EFI..."
    mkfs.vfat -F32 -n EFISYSTEM "$partpath" || {
      echo "Warning: Failed to format $partpath as FAT32"
    }
  elif [[ "$mp" == "/boot" ]] && [[ -d /sys/firmware/efi ]]; then
    echo "Auto-formatting $partpath as FAT32 for UEFI boot..."
    mkfs.vfat -F32 -n BOOT "$partpath" || {
      echo "Warning: Failed to format $partpath as FAT32"
    }
  fi
  
  log "Assigned $partpath to $mp"
  echo "Assigned $partpath to $mp"
  read -rp "Press Enter to continue..."
}

# -------------------------
# Remove Partition Assignment
# -------------------------
remove_partition_assignment() {
  local partpath="$1"
  local new_assignments=()
  for assignment in "${PART_ASSIGN[@]}"; do
    local part="${assignment%%:*}"
    if [[ "$part" != "$partpath" ]]; then
      new_assignments+=("$assignment")
    fi
  done
  PART_ASSIGN=("${new_assignments[@]}")
}

# -------------------------
# Create Partition Interactive
# -------------------------
create_partition_interactive() {
  echo "Opening cfdisk to create partitions on $DISK..."
  echo "Create your partitions and save, then exit cfdisk."
  read -rp "Press Enter to open cfdisk..."
  
  cfdisk "$DISK" || true
  
  echo "Returned from cfdisk."
  read -rp "Press Enter to continue..."
}

# -------------------------
# Format Partition Interactive
# -------------------------
format_partition_interactive() {
  local partpath="$1"
  
  local fs_type
  fs_type=$(printf "ext4\nbtrfs\nxfs\nf2fs\nvfat\nCancel" | eval "$FZF --prompt=\"Filesystem > \" --header=\"Choose filesystem for $partpath\"") || return
  
  if [[ "$fs_type" == "Cancel" ]]; then
    return
  fi
  
  echo "WARNING: This will erase all data on $partpath"
  read -rp "Type 'FORMAT' to confirm: " confirm
  if [[ "$confirm" != "FORMAT" ]]; then
    echo "Cancelled."
    read -rp "Press Enter to continue..."
    return
  fi
  
  case "$fs_type" in
    "ext4") mkfs.ext4 -F "$partpath" ;;
    "btrfs") mkfs.btrfs -f "$partpath" ;;
    "xfs") mkfs.xfs -f "$partpath" ;;
    "f2fs") mkfs.f2fs -f "$partpath" ;;
    "vfat") mkfs.vfat -F32 "$partpath" ;;
  esac
  
  echo "Partition formatted successfully!"
  read -rp "Press Enter to continue..."
}

# -------------------------
# Delete Specific Partition
# -------------------------
delete_specific_partition() {
  local partpath="$1"
  
  # Find which disk this partition belongs to by checking all available disks
  local target_disk=""
  local all_disks
  all_disks=$(lsblk -d -o NAME | awk 'NR>1 && $1!~/loop/ {print "/dev/"$1}')
  
  for disk in $all_disks; do
    if [[ "$partpath" =~ ^$disk ]]; then
      target_disk="$disk"
      break
    fi
  done
  
  if [[ -z "$target_disk" ]]; then
    echo "Could not determine which disk $partpath belongs to."
    read -rp "Press Enter to continue..."
    return
  fi
  
  local partnum=$(echo "$partpath" | sed "s|$target_disk||" | tr -d 'p')
  
  echo "WARNING: About to delete $partpath from $target_disk"
  read -rp "Type 'DELETE' to confirm: " confirm
  if [[ "$confirm" == "DELETE" ]]; then
    parted "$target_disk" rm "$partnum" 2>/dev/null || {
      echo "Failed to delete partition. Try using cfdisk manually."
    }
    # Remove from assignments
    remove_partition_assignment "$partpath"
    log "Deleted partition $partpath"
    echo "Partition deleted!"
  else
    echo "Deletion cancelled."
  fi
  read -rp "Press Enter to continue..."
}

# -------------------------
# Delete All Partitions
# -------------------------
delete_all_partitions() {
  echo "WARNING: This will delete ALL partitions on $DISK"
  echo "All data will be permanently lost!"
  echo
  printf "Type 'DELETE ALL' to confirm: "
  read -r confirm
  
  if [[ "$confirm" == "DELETE ALL" ]]; then
    # Unmount any mounted partitions
    echo "Unmounting partitions..."
    for partition in $(lsblk -lnp -o NAME "$DISK" | grep -E "${DISK}[0-9]+"); do
      if mountpoint -q "$partition" 2>/dev/null || grep -q "$partition" /proc/mounts; then
        echo "Unmounting $partition..."
        umount "$partition" 2>/dev/null || true
      fi
    done
    
    # Wipe partition table
    echo "Wiping partition table..."
    wipefs -a "$DISK" 2>/dev/null || true
    dd if=/dev/zero of="$DISK" bs=1M count=10 2>/dev/null || true
    
    # Clear all partition assignments for this disk
    local new_assignments=()
    for assignment in "${PART_ASSIGN[@]}"; do
      local part="${assignment%%:*}"
      if [[ ! "$part" =~ ^${DISK}[0-9]+ ]]; then
        new_assignments+=("$assignment")
      fi
    done
    PART_ASSIGN=("${new_assignments[@]}")
    
    echo "✓ All partitions deleted from $DISK"
    log "Deleted all partitions from $DISK"
  else
    echo "Deletion cancelled."
  fi
  
  read -rp "Press Enter to continue..."
}
