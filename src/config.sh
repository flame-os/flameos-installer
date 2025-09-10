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
MIRROR_REGION=""
AUDIO_DRIVER=""

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

# -------------------------
# Mirror Regions
# -------------------------
get_available_mirrors() {
  printf "Worldwide\nUnited States\nGermany\nFrance\nUnited Kingdom\nCanada\nAustralia\nJapan\nChina\nIndia"
}

get_mirror_url() {
  local region="$1"
  case "$region" in
    "United States")
      echo "https://mirror.rackspace.com/archlinux/"
      ;;
    "Germany")
      echo "https://ftp.fau.de/archlinux/"
      ;;
    "France")
      echo "https://archlinux.mailtunnel.eu/"
      ;;
    "United Kingdom")
      echo "https://www.mirrorservice.org/sites/ftp.archlinux.org/"
      ;;
    "Canada")
      echo "https://mirror.csclub.uwaterloo.ca/archlinux/"
      ;;
    "Australia")
      echo "https://mirror.aarnet.edu.au/pub/archlinux/"
      ;;
    "Japan")
      echo "https://ftp.jaist.ac.jp/pub/Linux/ArchLinux/"
      ;;
    "China")
      echo "https://mirrors.tuna.tsinghua.edu.cn/archlinux/"
      ;;
    "India")
      echo "https://mirror.cse.iitk.ac.in/archlinux/"
      ;;
    *)
      echo "https://geo.mirror.pkgbuild.com/"
      ;;
  esac
}

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
