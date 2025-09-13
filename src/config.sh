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
ADDITIONAL_PACKAGES=""
MIRROR_REGION=""
AUDIO_DRIVER=""
NETWORK_MANAGER=""
KERNEL=""
POWER_MANAGER=""
DISPLAY_MANAGER=""

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
  local desktop_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/workspaces"
  local desktops=()
  
  for script in "$desktop_dir"/*.sh; do
    if [[ -f "$script" ]]; then
      local name=""
      source "$script"
      [[ -n "$name" ]] && desktops+=("$name")
    fi
  done
  
  printf "%s\n" "${desktops[@]}"
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

# -------------------------
# Mirror Regions
# -------------------------
# -------------------------
# Audio Drivers
# -------------------------
get_available_audio() {
  printf "PulseAudio (Default)\nPipeWire (Modern)\nALSA Only (Minimal)"
}

get_audio_packages() {
  local driver="$1"
  case "$driver" in
    "PulseAudio (Default)")
      echo "pulseaudio pulseaudio-alsa pavucontrol"
      ;;
    "PipeWire (Modern)")
      echo "pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol"
      ;;
    "ALSA Only (Minimal)")
      echo "alsa-utils"
      ;;
    *)
      echo "pulseaudio pulseaudio-alsa pavucontrol"
      ;;
  esac
}

# -------------------------
# Network Managers
# -------------------------
get_available_network_managers() {
  printf "NetworkManager (Default)\niwctl"
}

# -------------------------
# Kernels
# -------------------------
get_available_kernels() {
  printf "linux\nlinux-zen\nlinux-lts"
}

# -------------------------
# Power Managers
# -------------------------
get_available_power_managers() {
  printf "power-profiles-daemon\ntlp"
}

get_power_packages() {
  local manager="$1"
  case "$manager" in
    "power-profiles-daemon")
      echo "power-profiles-daemon"
      ;;
    "tlp")
      echo "tlp tlp-rdw"
      ;;
    *)
      echo "power-profiles-daemon"
      ;;
  esac
}

# -------------------------
# Display Managers
# -------------------------
get_available_display_managers() {
  printf "sddm\nlightdm\ngdm"
}
