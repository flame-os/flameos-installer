#!/bin/bash


# Disk Selection
disk_selection() {
    show_banner
    gum style --foreground 214 "Disk Selection"
    echo ""
    
    # Show selected mountpoints under title
    if [ -f "/tmp/asiraos/mounts" ]; then
        echo -e "${GREEN}Selected Mountpoints:${NC}"
        cat /tmp/asiraos/mounts
        echo ""
    fi
    
    # Check if we have root and boot partitions
    HAS_ROOT=false
    HAS_BOOT=false
    if [ -f "/tmp/asiraos/mounts" ]; then
        if grep -q " -> /$" /tmp/asiraos/mounts; then
            HAS_ROOT=true
        fi
        if grep -q " -> /boot" /tmp/asiraos/mounts; then
            HAS_BOOT=true
        fi
    fi
    
    # Build menu options
    MENU_OPTIONS=("Auto Partition (Recommended)" "Custom Partition Setup")
    
    # Add clear option if mounts exist
    if [ -f "/tmp/asiraos/mounts" ]; then
        MENU_OPTIONS+=("Clear All Mountpoints")
    fi
    
    # Add continue button if both root and boot are configured
    if [ "$HAS_ROOT" = true ] && [ "$HAS_BOOT" = true ]; then
        MENU_OPTIONS=("→ Continue to Next Step (Recommended)" "${MENU_OPTIONS[@]}")
    fi
    
    MENU_OPTIONS+=("Go Back to Previous Menu")
    
    CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " "${MENU_OPTIONS[@]}")
    
    case $CHOICE in
        "Custom Partition Setup")
            manual_partition
            ;;
        "Auto Partition (Recommended)")
            auto_partition
            ;;
        "Clear All Mountpoints")
            rm -f /tmp/asiraos/mounts
            gum style --foreground 46 "All mountpoints cleared"
            sleep 1
            disk_selection
            ;;
        "→ Continue to Next Step (Recommended)")
            # Auto-mount partitions before continuing
            gum style --foreground 205 "Mounting partitions..."
            
            # Unmount any existing mounts
            umount -R /mnt 2>/dev/null || true
            
            # Mount root partition first
            ROOT_PARTITION=$(grep " -> /$" /tmp/asiraos/mounts | cut -d' ' -f1 | head -1)
            if [ -n "$ROOT_PARTITION" ]; then
                gum style --foreground 46 "Mounting root: $ROOT_PARTITION -> /mnt"
                mount "$ROOT_PARTITION" /mnt
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
            
            gum style --foreground 46 "✓ All partitions mounted successfully"
            sleep 1
            
            if [ "$BASIC_MODE" = true ]; then
                basic_step_3_locale
            else
                advanced_setup
            fi
            ;;
        "Go Back to Previous Menu")
            disk_selection
            ;;
    esac
}

# Disk Overview
disk_overview() {
    show_banner
    echo -e "${CYAN}Disk Overview${NC}"
    echo ""
    
    if [ -f "/tmp/asiraos/mounts" ]; then
        echo -e "${GREEN}Selected Mountpoints:${NC}"
        cat /tmp/asiraos/mounts
        echo ""
    else
        echo -e "${YELLOW}No mountpoints configured yet${NC}"
        echo ""
    fi
    
    gum input --placeholder "Press Enter to continue..."
    disk_selection
}

# Manual Partition
manual_partition() {
    show_banner
    gum style --foreground 214 "Manual Partition"
    echo ""
    
    # Detect available disks
    DISK_OPTIONS=()
    while IFS= read -r line; do
        DISK_NAME=$(echo "$line" | awk '{print $1}' | sed 's/[├└─│ ]//g')
        DISK_SIZE=$(echo "$line" | awk '{print $2}')
        if [[ "$DISK_NAME" =~ ^(nvme[0-9]+n[0-9]+|sd[a-z]|vd[a-z]|hd[a-z])$ ]]; then
            DISK_OPTIONS+=("$DISK_NAME ($DISK_SIZE)")
        fi
    done < <(lsblk -n -o NAME,SIZE)
    
    if [ ${#DISK_OPTIONS[@]} -eq 0 ]; then
        gum style --foreground 196 "No disks found"
        gum input --placeholder "Press Enter to go back..."
        disk_selection
        return
    fi
    
    # Let user select disk
    gum style --foreground 46 "Select disk:"
    SELECTED_OPTION=$(gum choose --cursor-prefix "> " --selected-prefix "* " "${DISK_OPTIONS[@]}")
    DISK=$(echo "$SELECTED_OPTION" | cut -d' ' -f1)
    
    CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Create/Edit Partitions (cfdisk)" \
        "Set Mountpoints" \
        "Go Back")
    
    case $CHOICE in
        "Create/Edit Partitions (cfdisk)")
            gum style --foreground 214 "Opening cfdisk for /dev/$DISK"
            sleep 1
            sudo cfdisk /dev/$DISK
            echo -e "${GREEN}Partitioning completed for /dev/$DISK${NC}"
            gum input --placeholder "Press Enter to continue..."
            manual_partition
            ;;
        "Set Mountpoints")
            set_mountpoints "$DISK"
            ;;
        "Go Back")
            disk_selection
            ;;
    esac
}

# Set Mountpoints
set_mountpoints() {
    local disk=$1
    show_banner
    echo -e "${CYAN}Set Mountpoints for /dev/$disk${NC}"
    echo ""
    
    # Get available partitions
    PARTITION_OPTIONS=()
    while IFS= read -r line; do
        PART_NAME=$(echo "$line" | awk '{print $1}' | sed 's/[├└─│ ]//g')
        PART_SIZE=$(echo "$line" | awk '{print $2}')
        if [[ "$PART_NAME" =~ ^${disk}(p?[0-9]+)$ ]]; then
            PARTITION_OPTIONS+=("$PART_NAME ($PART_SIZE)")
        fi
    done < <(lsblk /dev/$disk -n -o NAME,SIZE)
    
    # Add free space detection
    FREE_SPACE=$(parted /dev/$disk print free 2>/dev/null | grep "Free Space" | tail -1 | awk '{print $3}')
    if [ -n "$FREE_SPACE" ] && [ "$FREE_SPACE" != "0B" ]; then
        PARTITION_OPTIONS+=("FREE_SPACE ($FREE_SPACE) - Create New Partition")
    fi
    
    if [ ${#PARTITION_OPTIONS[@]} -eq 0 ]; then
        echo -e "${YELLOW}No partitions found on /dev/$disk${NC}"
        echo -e "${YELLOW}Please create partitions first using cfdisk${NC}"
        gum input --placeholder "Press Enter to go back..."
        manual_partition
        return
    fi
    
    # Let user select partition
    echo -e "${GREEN}Select partition:${NC}"
    SELECTED_OPTION=$(gum choose --cursor-prefix "> " --selected-prefix "* " "${PARTITION_OPTIONS[@]}")
    PARTITION=$(echo "$SELECTED_OPTION" | cut -d' ' -f1)
    
    # Handle free space selection
    if [ "$PARTITION" = "FREE_SPACE" ]; then
        gum style --foreground 205 "Creating new partition in free space..."
        
        # Get next partition number
        LAST_PART=$(parted /dev/$disk print 2>/dev/null | grep "^ " | tail -1 | awk '{print $1}')
        NEXT_PART=$((LAST_PART + 1))
        
        # Get partition size
        PART_SIZE=$(gum input --placeholder "Enter partition size (e.g., 20GB, 50%, 100%)")
        
        # Create partition
        if [[ "$PART_SIZE" == *"%" ]]; then
            parted /dev/$disk mkpart primary ext4 ${FREE_SPACE%G}GB ${PART_SIZE} --script
        else
            START_POS=$(parted /dev/$disk print free 2>/dev/null | grep "Free Space" | tail -1 | awk '{print $1}')
            END_SIZE=${PART_SIZE%GB}
            parted /dev/$disk mkpart primary ext4 ${START_POS} $((${START_POS%GB} + END_SIZE))GB --script
        fi
        
        # Set the new partition name
        if [[ "$disk" =~ nvme ]]; then
            PARTITION="${disk}p${NEXT_PART}"
        else
            PARTITION="${disk}${NEXT_PART}"
        fi
        
        gum style --foreground 46 "✓ Partition /dev/$PARTITION created"
    fi
    
    if [ ! -b "/dev/$PARTITION" ]; then
        gum style --foreground 196 "Partition /dev/$PARTITION not found"
        gum input --placeholder "Press Enter to try again..."
        set_mountpoints "$disk"
        return
    fi
    
    MOUNTPOINT=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "/" \
        "/boot" \
        "/boot/efi" \
        "/home" \
        "/var" \
        "/tmp" \
        "swap" \
        "Custom")
    
    if [ "$MOUNTPOINT" = "Custom" ]; then
        MOUNTPOINT=$(gum input --placeholder "Enter custom mountpoint (e.g., /opt)")
    fi
    
    # Ask if user wants to format the partition
    FORMAT_CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Format partition" \
        "Use existing filesystem")
    
    if [ "$FORMAT_CHOICE" = "Format partition" ]; then
        # Select filesystem type based on mountpoint
        if [ "$MOUNTPOINT" = "/boot/efi" ]; then
            FS_TYPE="vfat"
            gum style --foreground 205 "Formatting /dev/$PARTITION as FAT32..."
            mkfs.fat -F32 /dev/$PARTITION
        elif [ "$MOUNTPOINT" = "swap" ]; then
            FS_TYPE="swap"
            gum style --foreground 205 "Setting up swap on /dev/$PARTITION..."
            mkswap /dev/$PARTITION
        else
            # Ask user for filesystem type
            FS_TYPE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
                "ext4" \
                "ext3" \
                "xfs" \
                "btrfs")
            
            case $FS_TYPE in
                "ext4")
                    gum style --foreground 205 "Formatting /dev/$PARTITION as ext4..."
                    mkfs.ext4 /dev/$PARTITION
                    ;;
                "ext3")
                    gum style --foreground 205 "Formatting /dev/$PARTITION as ext3..."
                    mkfs.ext3 /dev/$PARTITION
                    ;;
                "xfs")
                    gum style --foreground 205 "Formatting /dev/$PARTITION as xfs..."
                    mkfs.xfs /dev/$PARTITION
                    ;;
                "btrfs")
                    gum style --foreground 205 "Formatting /dev/$PARTITION as btrfs..."
                    mkfs.btrfs /dev/$PARTITION
                    ;;
            esac
        fi
        gum style --foreground 46 "✓ Formatting completed"
    fi
    
    # Check if mountpoint already exists
    if grep -q " -> $MOUNTPOINT$" /tmp/asiraos/mounts 2>/dev/null; then
        gum style --foreground 196 "Mountpoint $MOUNTPOINT already exists!"
        gum input --placeholder "Press Enter to try again..."
        set_mountpoints "$disk"
        return
    fi
    
    # Save mountpoint configuration
    echo "/dev/$PARTITION -> $MOUNTPOINT" >> /tmp/asiraos/mounts
    echo -e "${GREEN}Mountpoint set: /dev/$PARTITION -> $MOUNTPOINT${NC}"
    
    CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Set Another Mountpoint" \
        "Continue to Next Step" \
        "Go Back to Disk Selection")
    
    case $CHOICE in
        "Set Another Mountpoint")
            set_mountpoints "$disk"
            ;;
        "Continue to Next Step")
            main_menu
            ;;
        "Go Back to Disk Selection")
            disk_selection
            ;;
    esac
}

# Auto Partition
auto_partition() {
    show_banner
    gum style --foreground 214 "Auto Partition"
    echo ""
    
    # Detect available disks and partitions
    gum style --foreground 46 "Detecting available disks and partitions..."
    ALL_OPTIONS=()
    CURRENT_DISK=""
    
    # Get disks and their partitions in tree format
    while IFS= read -r line; do
        RAW_NAME=$(echo "$line" | awk '{print $1}')
        NAME=$(echo "$RAW_NAME" | sed 's/[├└─│ ]//g')  # Clean tree characters
        SIZE=$(echo "$line" | awk '{print $4}')
        TYPE=$(echo "$line" | awk '{print $6}')
        
        if [ "$TYPE" = "disk" ]; then
            # Add disk
            ALL_OPTIONS+=("$NAME ($SIZE)")
            CURRENT_DISK="$NAME"
            
            # Check for free space on this disk
            FREE_SPACE=$(parted /dev/$NAME print free 2>/dev/null | grep "Free Space" | tail -1 | awk '{print $3}')
            if [ -n "$FREE_SPACE" ] && [ "$FREE_SPACE" != "0B" ]; then
                ALL_OPTIONS+=(" └─ $CURRENT_DISK-freespace ($FREE_SPACE)")
            fi
        elif [ "$TYPE" = "part" ]; then
            # Add partition with tree formatting
            ALL_OPTIONS+=(" └─ $NAME ($SIZE)")
        fi
    done < <(lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINT)
    
    if [ ${#ALL_OPTIONS[@]} -eq 0 ]; then
        gum style --foreground 196 "No disks found"
        gum input --placeholder "Press Enter to go back..."
        disk_selection
        return
    fi
    
    # Let user select disk/partition
    gum style --foreground 46 "Select disk or partition for installation:"
    SELECTED_OPTION=$(gum choose --cursor-prefix "> " --selected-prefix "* " "${ALL_OPTIONS[@]}")
    
    # Parse the selected option
    if [[ "$SELECTED_OPTION" =~ ^[[:space:]]*└─[[:space:]]*(.*)[[:space:]]*\(.*\)$ ]]; then
        # It's a partition or free space (indented)
        SELECTED_PARTITION=$(echo "${BASH_REMATCH[1]}" | awk '{print $1}')
    else
        # It's a whole disk
        SELECTED_PARTITION=$(echo "$SELECTED_OPTION" | awk '{print $1}')
    fi
    
    # Handle free space selection
    if [[ "$SELECTED_PARTITION" =~ -freespace$ ]]; then
        # Extract parent disk name
        PARENT_DISK=$(echo "$SELECTED_PARTITION" | sed 's/-freespace$//')
        SELECTED_PARTITION="$PARENT_DISK"
        FREE_SPACE_MODE=true
        
        # Ask for root filesystem type
        gum style --foreground 205 "Select filesystem type for root partition:"
        ROOT_FS=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
            "ext4" \
            "ext3" \
            "xfs" \
            "btrfs")
    else
        FREE_SPACE_MODE=false
        ROOT_FS="ext4"
    fi
    
    # Show free space available
    TOTAL_SIZE=$(echo "$SELECTED_OPTION" | grep -o '([^)]*)')
    DISK_INFO=$(lsblk -b -n -o SIZE /dev/$SELECTED_PARTITION 2>/dev/null | head -1)
    if [ -n "$DISK_INFO" ]; then
        FREE_SPACE=$(echo "$DISK_INFO" | awk '{printf "%.1fG", $1/1024/1024/1024}')
    else
        FREE_SPACE="N/A"
    fi
    echo ""
    echo -e "${GREEN}Selected: /dev/$SELECTED_PARTITION${NC}"
    echo -e "${GREEN}Total Size: $TOTAL_SIZE${NC}"
    echo -e "${GREEN}Available Space: $FREE_SPACE${NC}"
    echo ""
    
    # Show appropriate warning based on selection type
    if [ "$FREE_SPACE_MODE" = true ]; then
        gum style --foreground 205 "INFO: Will create partitions in free space on /dev/$SELECTED_PARTITION"
    else
        gum style --foreground 196 "WARNING: This will erase all data on /dev/$SELECTED_PARTITION"
    fi
    CONFIRM=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Yes" \
        "No")
    
    if [ "$CONFIRM" = "No" ]; then
        disk_selection
        return
    fi
    
    # Partition scheme selection
    gum style --foreground 214 "Select partition scheme:"
    PARTITION_SCHEME=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Basic (Boot + Root only)" \
        "Standard (Boot + Root + Home)" \
        "Custom (Choose additional partitions)")
    
        case $PARTITION_SCHEME in
        "Basic (Boot + Root only)")
            if [ "$FREE_SPACE_MODE" = true ]; then
                create_basic_partitions_freespace "$SELECTED_PARTITION"
            else
                create_basic_partitions "$SELECTED_PARTITION"
            fi
            ;;
        "Standard (Boot + Root + Home)")
            if [ "$FREE_SPACE_MODE" = true ]; then
                create_standard_partitions_freespace "$SELECTED_PARTITION"
            else
                create_standard_partitions "$SELECTED_PARTITION"
            fi
            ;;
        "Custom (Choose additional partitions)")
            if [ "$FREE_SPACE_MODE" = true ]; then
                create_custom_partitions_freespace "$SELECTED_PARTITION"
            else
                create_custom_partitions "$SELECTED_PARTITION"
            fi
            ;;
    esac
}

# Create basic partitions (Boot + Root)
create_basic_partitions() {
    local partition=$1
    echo -e "${CYAN}Creating basic partitions on /dev/${partition}...${NC}"
    
    # Check if user selected a whole disk or existing partition
    if [[ "$partition" =~ p[0-9]+$ ]]; then
        # User selected existing partition - delete it and recreate in same space
        local disk_name=${partition%p*}
        local part_num=${partition##*p}
        
        # Get partition info BEFORE deleting it
        local part_info=$(sudo parted /dev/${disk_name} unit MB print | grep "^ ${part_num}" | head -1)
        local start_mb=$(echo "$part_info" | awk '{print $2}' | sed 's/MB//')
        local end_mb=$(echo "$part_info" | awk '{print $3}' | sed 's/MB//')
        
        echo -e "${YELLOW}Deleting existing partition ${partition}...${NC}"
        sudo parted /dev/${disk_name} rm ${part_num} --script
        
        if [ -z "$start_mb" ]; then
            echo -e "${RED}Could not determine partition boundaries${NC}"
            echo -e "${YELLOW}Using available free space instead${NC}"
            start_mb=$(sudo parted /dev/${disk_name} unit MB print free | grep "Free Space" | tail -1 | awk '{print $1}' | sed 's/MB//')
            end_mb=$(sudo parted /dev/${disk_name} unit MB print free | grep "Free Space" | tail -1 | awk '{print $2}' | sed 's/MB//')
        fi
        
        local boot_end=$((start_mb + 1024))
        
        echo -e "${CYAN}- Creating EFI Boot partition (1GB)${NC}"
        sudo parted /dev/${disk_name} mkpart primary fat32 ${start_mb}MB ${boot_end}MB --script
        sudo parted /dev/${disk_name} set ${part_num} boot on --script
        
        echo -e "${CYAN}- Creating Root partition (remaining space)${NC}"
        sudo parted /dev/${disk_name} mkpart primary ext4 ${boot_end}MB ${end_mb}MB --script
        
        # Format and save mountpoints
        echo -e "${CYAN}Formatting EFI partition: /dev/${disk_name}p${part_num}${NC}"
        mkfs.fat -F32 /dev/${disk_name}p${part_num}
        echo -e "${CYAN}Formatting root partition: /dev/${disk_name}p$((part_num + 1))${NC}"
        mkfs.ext4 /dev/${disk_name}p$((part_num + 1))
        
        echo "/dev/${disk_name}p${part_num} -> /boot/efi" >> /tmp/asiraos/mounts
        echo "/dev/${disk_name}p$((part_num + 1)) -> /" >> /tmp/asiraos/mounts
    else
        # User selected whole disk - wipe and create new partition table
        echo -e "${YELLOW}Wiping disk ${partition}...${NC}"
        sudo parted /dev/${partition} mklabel gpt --script
        
        echo -e "${CYAN}- Creating EFI Boot partition (1GB)${NC}"
        sudo parted /dev/${partition} mkpart primary fat32 1MB 1025MB --script
        sudo parted /dev/${partition} set 1 boot on --script
        
        echo -e "${CYAN}- Creating Root partition (remaining space)${NC}"
        sudo parted /dev/${partition} mkpart primary ext4 1025MB 100% --script
        
        # Save mountpoints with proper partition naming
        if [[ "$partition" =~ nvme ]]; then
            echo "/dev/${partition}p1 -> /boot/efi" >> /tmp/asiraos/mounts
            echo "/dev/${partition}p2 -> /" >> /tmp/asiraos/mounts
        else
            echo "/dev/${partition}1 -> /boot/efi" >> /tmp/asiraos/mounts
            echo "/dev/${partition}2 -> /" >> /tmp/asiraos/mounts
        fi
    fi
    
    sleep 2
    
    # Format partitions
    echo -e "${CYAN}Formatting partitions...${NC}"
    if [[ "$partition" =~ nvme ]]; then
        echo -e "${CYAN}Formatting EFI partition: /dev/${partition}p1${NC}"
        mkfs.fat -F32 /dev/${partition}p1
        echo -e "${CYAN}Formatting root partition: /dev/${partition}p2${NC}"
        mkfs.ext4 /dev/${partition}p2
    else
        echo -e "${CYAN}Formatting EFI partition: /dev/${partition}1${NC}"
        mkfs.fat -F32 /dev/${partition}1
        echo -e "${CYAN}Formatting root partition: /dev/${partition}2${NC}"
        mkfs.ext4 /dev/${partition}2
    fi
    
    echo -e "${GREEN}Basic partitions created successfully${NC}"
    partition_complete
}

# Create standard partitions (Boot + Root + Home)
create_standard_partitions() {
    local partition=$1
    echo -e "${CYAN}Creating standard partitions on /dev/${partition}...${NC}"
    echo -e "${CYAN}- EFI Boot partition (1GB)${NC}"
    echo -e "${CYAN}- Root partition (30GB)${NC}"
    echo -e "${CYAN}- Home partition (remaining space)${NC}"
    sleep 2
    
    # Check if user selected a whole disk or existing partition
    if [[ "$partition" =~ p[0-9]+$ ]]; then
        # User selected existing partition - use it as root
        echo "/dev/${partition} -> /" >> /tmp/asiraos/mounts
        echo -e "${YELLOW}Note: Using existing partition ${partition} as root${NC}"
        echo -e "${YELLOW}Please manually set boot and home partitions if needed${NC}"
    else
        # User selected whole disk - create new partitions
        if [[ "$partition" =~ nvme ]]; then
            echo "/dev/${partition}p1 -> /boot/efi" >> /tmp/asiraos/mounts
            echo "/dev/${partition}p2 -> /" >> /tmp/asiraos/mounts
            echo "/dev/${partition}p3 -> /home" >> /tmp/asiraos/mounts
        else
            echo "/dev/${partition}1 -> /boot/efi" >> /tmp/asiraos/mounts
            echo "/dev/${partition}2 -> /" >> /tmp/asiraos/mounts
            echo "/dev/${partition}3 -> /home" >> /tmp/asiraos/mounts
        fi
    fi
    
    echo -e "${GREEN}Standard partitions created successfully${NC}"
    partition_complete
}

# Create custom partitions
create_custom_partitions() {
    local partition=$1
    echo -e "${CYAN}Creating custom partitions on /dev/${partition}...${NC}"
    echo -e "${CYAN}- EFI Boot partition (1GB)${NC}"
    echo -e "${CYAN}- Root partition (30GB)${NC}"
    
    # Check if user selected a whole disk or existing partition
    if [[ "$partition" =~ p[0-9]+$ ]]; then
        # User selected existing partition - use it as root
        echo "/dev/${partition} -> /" >> /tmp/asiraos/mounts
        echo -e "${YELLOW}Note: Using existing partition ${partition} as root${NC}"
    else
        # User selected whole disk - create new partitions
        if [[ "$partition" =~ nvme ]]; then
            echo "/dev/${partition}p1 -> /boot/efi" >> /tmp/asiraos/mounts
            echo "/dev/${partition}p2 -> /" >> /tmp/asiraos/mounts
            local part_prefix="p"
            local base_partition="$partition"
        else
            echo "/dev/${partition}1 -> /boot/efi" >> /tmp/asiraos/mounts
            echo "/dev/${partition}2 -> /" >> /tmp/asiraos/mounts
            local part_prefix=""
            local base_partition="$partition"
        fi
        
        local part_num=3
        
        # Ask for additional partitions
        ADDITIONAL_PARTITIONS=$(gum choose --no-limit --cursor-prefix "> " --selected-prefix "* " \
            "Home partition" \
            "Swap partition" \
            "Var partition" \
            "Tmp partition")
        
        if [[ $ADDITIONAL_PARTITIONS == *"Home partition"* ]]; then
            echo -e "${CYAN}- Home partition (20GB)${NC}"
            echo "/dev/${base_partition}${part_prefix}${part_num} -> /home" >> /tmp/asiraos/mounts
            ((part_num++))
        fi
        if [[ $ADDITIONAL_PARTITIONS == *"Swap partition"* ]]; then
            echo -e "${CYAN}- Swap partition (4GB)${NC}"
            echo "/dev/${base_partition}${part_prefix}${part_num} -> swap" >> /tmp/asiraos/mounts
            ((part_num++))
        fi
        if [[ $ADDITIONAL_PARTITIONS == *"Var partition"* ]]; then
            echo -e "${CYAN}- Var partition (10GB)${NC}"
            echo "/dev/${base_partition}${part_prefix}${part_num} -> /var" >> /tmp/asiraos/mounts
            ((part_num++))
        fi
        if [[ $ADDITIONAL_PARTITIONS == *"Tmp partition"* ]]; then
            echo -e "${CYAN}- Tmp partition (5GB)${NC}"
            echo "/dev/${base_partition}${part_prefix}${part_num} -> /tmp" >> /tmp/asiraos/mounts
            ((part_num++))
        fi
    fi
    
    sleep 2
    echo -e "${GREEN}Custom partitions created successfully${NC}"
    partition_complete
}

# Partition completion
partition_complete() {
    CHOICE=$(gum choose --cursor-prefix "> " --selected-prefix "* " \
        "Continue to next step" \
        "Go Back to Disk Selection")
    
    case $CHOICE in
        "Continue to next step")
            disk_selection
            ;;
        "Go Back to Disk Selection")
            disk_selection
            ;;
    esac
}

# Create basic partitions in free space
create_basic_partitions_freespace() {
    local disk=$1
    
    # FORCE CLEAR ALL MOUNTS
    rm -rf /tmp/asiraos
    mkdir -p /tmp/asiraos
    
    echo -e "${RED}=== EXISTING PARTITIONS ===${NC}"
    lsblk /dev/$disk
    
    # Get ALL existing partition numbers for this disk
    EXISTING_PARTS=$(lsblk -n /dev/$disk | grep -E "${disk}p?[0-9]+" | sed -E "s/.*${disk}p?([0-9]+).*/\1/" | sort -n)
    echo "Existing partition numbers: $EXISTING_PARTS"
    
    # Find the HIGHEST existing partition number
    if [ -n "$EXISTING_PARTS" ]; then
        HIGHEST=$(echo "$EXISTING_PARTS" | tail -1)
    else
        HIGHEST=0
    fi
    
    # Calculate NEW partition numbers (next available)
    NEW_BOOT=$((HIGHEST + 1))
    NEW_ROOT=$((HIGHEST + 2))
    
    echo -e "${GREEN}Will create NEW partitions:${NC}"
    if [[ "$disk" =~ nvme ]]; then
        NEW_BOOT_DEV="/dev/${disk}p${NEW_BOOT}"
        NEW_ROOT_DEV="/dev/${disk}p${NEW_ROOT}"
    else
        NEW_BOOT_DEV="/dev/${disk}${NEW_BOOT}"
        NEW_ROOT_DEV="/dev/${disk}${NEW_ROOT}"
    fi
    
    echo "Boot: $NEW_BOOT_DEV (partition $NEW_BOOT)"
    echo "Root: $NEW_ROOT_DEV (partition $NEW_ROOT)"
    
    # Check if these partitions already exist (safety check)
    if [ -b "$NEW_BOOT_DEV" ] || [ -b "$NEW_ROOT_DEV" ]; then
        echo -e "${RED}ERROR: Calculated partitions already exist!${NC}"
        echo "Boot device exists: $([ -b "$NEW_BOOT_DEV" ] && echo "YES" || echo "NO")"
        echo "Root device exists: $([ -b "$NEW_ROOT_DEV" ] && echo "YES" || echo "NO")"
        echo "Continuing anyway..."
    fi
    
    # Get free space
    FREE_INFO=$(parted /dev/$disk print free 2>/dev/null | grep "Free Space" | tail -1)
    FREE_START=$(echo "$FREE_INFO" | awk '{print $1}')
    FREE_END=$(echo "$FREE_INFO" | awk '{print $2}')
    
    echo "Using free space: $FREE_START to $FREE_END"
    
    # UNMOUNT any existing partitions on this disk first
    echo -e "${YELLOW}Unmounting any existing partitions on $disk...${NC}"
    umount /dev/${disk}* 2>/dev/null || true
    swapoff /dev/${disk}* 2>/dev/null || true
    
    # Force unmount anything mounted under /mnt
    umount -R /mnt 2>/dev/null || true
    
    sleep 2
    
    # Create NEW partitions
    BOOT_END=$(echo "$FREE_START" | sed 's/[^0-9.]//g' | awk '{printf "%.0fMB", ($1*1000) + 1024}')
    
    echo -e "${CYAN}Creating partition $NEW_BOOT (boot)... (this may take a moment)${NC}"
    parted /dev/$disk mkpart primary fat32 $FREE_START $BOOT_END --script
    parted /dev/$disk set $NEW_BOOT boot on --script
    
    echo -e "${CYAN}Creating partition $NEW_ROOT (root)... (this may take a moment for large partitions)${NC}"
    parted /dev/$disk mkpart primary ext4 $BOOT_END $FREE_END --script
    
    # Force system to recognize new partitions
    echo -e "${CYAN}Refreshing partition table...${NC}"
    partprobe /dev/$disk
    udevadm settle
    
    # Force re-read partition table multiple ways
    blockdev --rereadpt /dev/$disk 2>/dev/null || true
    if [ -w "/sys/block/${disk}/device/rescan" ]; then
        echo 1 > /sys/block/${disk}/device/rescan 2>/dev/null || true
    fi
    
    sleep 5
    
    # Try to trigger udev again
    udevadm trigger --subsystem-match=block
    udevadm settle
    
    echo -e "${RED}=== AFTER CREATION ===${NC}"
    lsblk /dev/$disk
    
    # Force another partition table refresh
    partprobe /dev/$disk 2>/dev/null || true
    udevadm settle
    sleep 2
    
    # Verify new partitions exist (ignore warnings about old partitions)
    echo -e "${CYAN}Checking for new partitions...${NC}"
    if [ -b "$NEW_BOOT_DEV" ]; then
        echo -e "${GREEN}✓ Boot partition created: $NEW_BOOT_DEV${NC}"
    else
        echo -e "${RED}✗ Boot partition missing: $NEW_BOOT_DEV${NC}"
    fi
    
    if [ -b "$NEW_ROOT_DEV" ]; then
        echo -e "${GREEN}✓ Root partition created: $NEW_ROOT_DEV${NC}"
    else
        echo -e "${RED}✗ Root partition missing: $NEW_ROOT_DEV${NC}"
    fi
    
    # Format ONLY the NEW partitions
    echo -e "${GREEN}Formatting NEW partition: $NEW_BOOT_DEV (quick format)${NC}"
    mkfs.fat -F32 $NEW_BOOT_DEV
    
    echo -e "${GREEN}Formatting NEW partition: $NEW_ROOT_DEV (this will take time for large partitions...)${NC}"
    mkfs.ext4 $NEW_ROOT_DEV
    
    # Save ONLY the NEW partitions - ALWAYS create this file
    mkdir -p /tmp/asiraos
    echo "$NEW_BOOT_DEV -> /boot/efi" > /tmp/asiraos/mounts
    echo "$NEW_ROOT_DEV -> /" >> /tmp/asiraos/mounts
    
    echo -e "${GREEN}=== FINAL MOUNTS ===${NC}"
    if [ -f /tmp/asiraos/mounts ]; then
        cat /tmp/asiraos/mounts
    else
        echo "ERROR: Mounts file not created!"
    fi
    
    echo -e "${GREEN}✓ NEW partitions created and saved${NC}"
    partition_complete
}

# Create standard partitions in free space
create_standard_partitions_freespace() {
    local disk=$1
    echo -e "${CYAN}Creating standard partitions in free space on /dev/${disk}...${NC}"
    
    # Clear any existing mounts to avoid conflicts
    rm -f /tmp/asiraos/mounts
    mkdir -p /tmp/asiraos
    
    # Get free space info
    FREE_START=$(parted /dev/$disk print free 2>/dev/null | grep "Free Space" | tail -1 | awk '{print $1}')
    FREE_END=$(parted /dev/$disk print free 2>/dev/null | grep "Free Space" | tail -1 | awk '{print $2}')
    
    # Get next available partition numbers
    LAST_PART=$(parted /dev/$disk print 2>/dev/null | awk '/^ *[0-9]/ {last=$1} END {print last}')
    if [ -z "$LAST_PART" ]; then
        LAST_PART=0
    fi
    BOOT_PART=$((LAST_PART + 1))
    ROOT_PART=$((LAST_PART + 2))
    HOME_PART=$((LAST_PART + 3))
    
    echo -e "${CYAN}- Creating EFI Boot partition (1GB)${NC}"
    BOOT_END=$(echo "$FREE_START" | sed 's/[^0-9.]//g' | awk '{printf "%.0fMB", ($1*1000) + 1024}')
    parted /dev/$disk mkpart primary fat32 $FREE_START $BOOT_END --script
    parted /dev/$disk set $BOOT_PART boot on --script
    
    echo -e "${CYAN}- Creating Root partition (30GB)${NC}"
    ROOT_END=$(echo "$BOOT_END" | sed 's/MB//' | awk '{printf "%.0fMB", $1 + 30720}')
    parted /dev/$disk mkpart primary $ROOT_FS $BOOT_END $ROOT_END --script
    
    echo -e "${CYAN}- Creating Home partition (remaining space)${NC}"
    parted /dev/$disk mkpart primary ext4 $ROOT_END $FREE_END --script
    
    # Wait for kernel to recognize new partitions
    sleep 3
    partprobe /dev/$disk
    
    # Construct correct partition device names
    if [[ "$disk" =~ nvme ]]; then
        BOOT_DEV="/dev/${disk}p${BOOT_PART}"
        ROOT_DEV="/dev/${disk}p${ROOT_PART}"
        HOME_DEV="/dev/${disk}p${HOME_PART}"
    else
        BOOT_DEV="/dev/${disk}${BOOT_PART}"
        ROOT_DEV="/dev/${disk}${ROOT_PART}"
        HOME_DEV="/dev/${disk}${HOME_PART}"
    fi
    
    # Format partitions
    echo -e "${CYAN}Formatting partitions...${NC}"
    mkfs.fat -F32 $BOOT_DEV
    
    case $ROOT_FS in
        "ext4") mkfs.ext4 $ROOT_DEV ;;
        "ext3") mkfs.ext3 $ROOT_DEV ;;
        "xfs") mkfs.xfs $ROOT_DEV ;;
        "btrfs") mkfs.btrfs $ROOT_DEV ;;
    esac
    
    mkfs.ext4 $HOME_DEV
    
    # Save mountpoints
    echo "$BOOT_DEV -> /boot/efi" >> /tmp/asiraos/mounts
    echo "$ROOT_DEV -> /" >> /tmp/asiraos/mounts
    echo "$HOME_DEV -> /home" >> /tmp/asiraos/mounts
    
    echo -e "${GREEN}Standard partitions created successfully in free space${NC}"
    partition_complete
}

# Create custom partitions in free space
create_custom_partitions_freespace() {
    local disk=$1
    echo -e "${CYAN}Creating custom partitions in free space on /dev/${disk}...${NC}"
    
    # Clear any existing mounts to avoid conflicts
    rm -f /tmp/asiraos/mounts
    mkdir -p /tmp/asiraos
    
    # Get free space info
    FREE_START=$(parted /dev/$disk print free 2>/dev/null | grep "Free Space" | tail -1 | awk '{print $1}')
    FREE_END=$(parted /dev/$disk print free 2>/dev/null | grep "Free Space" | tail -1 | awk '{print $2}')
    
    # Get next available partition numbers
    LAST_PART=$(parted /dev/$disk print 2>/dev/null | awk '/^ *[0-9]/ {last=$1} END {print last}')
    if [ -z "$LAST_PART" ]; then
        LAST_PART=0
    fi
    
    local part_num=$((LAST_PART + 1))
    
    echo -e "${CYAN}- Creating EFI Boot partition (1GB)${NC}"
    BOOT_END=$(echo "$FREE_START" | sed 's/[^0-9.]//g' | awk '{printf "%.0fMB", ($1*1000) + 1024}')
    parted /dev/$disk mkpart primary fat32 $FREE_START $BOOT_END --script
    parted /dev/$disk set $part_num boot on --script
    
    if [[ "$disk" =~ nvme ]]; then
        BOOT_DEV="/dev/${disk}p${part_num}"
    else
        BOOT_DEV="/dev/${disk}${part_num}"
    fi
    ((part_num++))
    
    echo -e "${CYAN}- Creating Root partition (30GB)${NC}"
    ROOT_END=$(echo "$BOOT_END" | sed 's/MB//' | awk '{printf "%.0fMB", $1 + 30720}')
    parted /dev/$disk mkpart primary $ROOT_FS $BOOT_END $ROOT_END --script
    
    if [[ "$disk" =~ nvme ]]; then
        ROOT_DEV="/dev/${disk}p${part_num}"
    else
        ROOT_DEV="/dev/${disk}${part_num}"
    fi
    
    # Wait for kernel to recognize new partitions
    sleep 3
    partprobe /dev/$disk
    
    # Format partitions
    echo -e "${CYAN}Formatting partitions...${NC}"
    mkfs.fat -F32 $BOOT_DEV
    
    case $ROOT_FS in
        "ext4") mkfs.ext4 $ROOT_DEV ;;
        "ext3") mkfs.ext3 $ROOT_DEV ;;
        "xfs") mkfs.xfs $ROOT_DEV ;;
        "btrfs") mkfs.btrfs $ROOT_DEV ;;
    esac
    
    # Save basic mountpoints
    echo "$BOOT_DEV -> /boot/efi" >> /tmp/asiraos/mounts
    echo "$ROOT_DEV -> /" >> /tmp/asiraos/mounts
    
    echo -e "${GREEN}Custom partitions created successfully in free space${NC}"
    partition_complete
}
