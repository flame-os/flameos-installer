#!/usr/bin/env bash

# FlameOS Installer - Configuration
# Global variables and settings

# -------------------------
# Global Variables
# -------------------------
DISK=""
PART_ASSIGN=()   # array entries like "/dev/sda1:/"
EFI_PART=""
ROOT_PART=""
SWAP_PART=""
HOME_PART=""

USERNAME=""
PASSWORD=""
HOSTNAME=""
TIMEZONE=""
LOCALE=""
DESKTOP=""
GRAPHICS_PACKAGES=""

# -------------------------
# Configuration / styling
# -------------------------
FZF="fzf --border=rounded --reverse --height=60% --margin=1,20% --layout=reverse --info=inline"
CLEAR_ON_SHOW=true

# -------------------------
# Logging
# -------------------------
LOGFILE="$HOME/flameos-install.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

# -------------------------
# Desktop Environments
# -------------------------
get_available_desktops() {
  printf "Hyprland\nKDE Plasma\nGNOME\nXFCE\ni3\nSway\nMinimal"
}

# -------------------------
# Graphics Drivers
# -------------------------
get_graphics_packages() {
  local driver="$1"
  case "$driver" in
    "NVIDIA (Proprietary)")
      echo "nvidia nvidia-utils nvidia-settings"
      ;;
    "AMD (Open Source)")
      echo "mesa xf86-video-amdgpu vulkan-radeon"
      ;;
    "Intel (Open Source)")
      echo "mesa xf86-video-intel vulkan-intel"
      ;;
    "Generic (VESA)")
      echo "xf86-video-vesa"
      ;;
    *)
      echo ""
      ;;
  esac
}
