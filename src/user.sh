#!/usr/bin/env bash

# FlameOS Installer - User Configuration
# User account, system settings, and desktop environment

# -------------------------
# User Configuration Step
# -------------------------
user_config_step() {
  show_banner "Step: User Configuration"
  
  while true; do
    echo "Current settings:"
    echo " Username: ${USERNAME:-not set}"
    echo " Hostname: ${HOSTNAME:-not set}"
    echo
    
    local choice
    choice=$(printf "Set Username\nSet Password\nSet Hostname\nContinue\nGo Back" | eval "$FZF --prompt=\"User Config > \" --header=\"Configure user settings\"") || return 1
    
    case "$choice" in
      "Set Username")
        set_username
        ;;
      "Set Password")
        set_password
        ;;
      "Set Hostname")
        set_hostname
        ;;
      "Continue")
        if [[ -z "$USERNAME" ]]; then
          echo "Username is required!"
          read -rp "Press Enter to continue..."
          continue
        fi
        if [[ -z "$PASSWORD" ]]; then
          echo "Password is required!"
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
# Username Configuration
# -------------------------
set_username() {
  while true; do
    read -rp "Enter username: " USERNAME
    
    if [[ -z "$USERNAME" ]]; then
      echo "Username cannot be empty"
      continue
    fi
    
    if [[ ! "$USERNAME" =~ ^[a-z][a-z0-9_-]*$ ]]; then
      echo "Username must start with a letter and contain only lowercase letters, numbers, hyphens, and underscores"
      continue
    fi
    
    if [[ ${#USERNAME} -gt 32 ]]; then
      echo "Username must be 32 characters or less"
      continue
    fi
    
    log "Username set to: $USERNAME"
    break
  done
}

# -------------------------
# Password Configuration
# -------------------------
set_password() {
  while true; do
    read -rsp "Enter password: " PASSWORD
    echo
    
    if [[ -z "$PASSWORD" ]]; then
      echo "Password cannot be empty"
      continue
    fi
    
    if [[ ${#PASSWORD} -lt 4 ]]; then
      echo "Password must be at least 4 characters"
      continue
    fi
    
    read -rsp "Confirm password: " password_confirm
    echo
    
    if [[ "$PASSWORD" != "$password_confirm" ]]; then
      echo "Passwords do not match"
      continue
    fi
    
    log "Password set successfully"
    break
  done
}

# -------------------------
# Hostname Configuration
# -------------------------
set_hostname() {
  while true; do
    read -rp "Enter hostname [flameos]: " HOSTNAME
    
    if [[ -z "$HOSTNAME" ]]; then
      HOSTNAME="flameos"
    fi
    
    if [[ ! "$HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$ ]]; then
      echo "Hostname must contain only letters, numbers, and hyphens"
      continue
    fi
    
    if [[ ${#HOSTNAME} -gt 63 ]]; then
      echo "Hostname must be 63 characters or less"
      continue
    fi
    
    log "Hostname set to: $HOSTNAME"
    break
  done
}

# -------------------------
# System Configuration Step
# -------------------------
system_config_step() {
  show_banner "Step: System Configuration"
  
  while true; do
    echo "Current settings:"
    echo " Timezone: ${TIMEZONE:-not set}"
    echo " Locale: ${LOCALE:-not set}"
    echo " Mirror Region: ${MIRROR_REGION:-not set}"
    echo
    
    local choice
    choice=$(printf "Set Timezone\nSet Locale\nSet Mirror Region\nContinue\nGo Back" | eval "$FZF --prompt=\"System Config > \" --header=\"Configure system settings\"") || return 1
    
    case "$choice" in
      "Set Timezone")
        set_timezone
        ;;
      "Set Locale")
        set_locale
        ;;
      "Set Mirror Region")
        set_mirror_region
        ;;
      "Continue")
        if [[ -z "$TIMEZONE" ]]; then
          TIMEZONE="UTC"
          log "Timezone defaulted to: $TIMEZONE"
        fi
        if [[ -z "$LOCALE" ]]; then
          LOCALE="en_US.UTF-8"
          log "Locale defaulted to: $LOCALE"
        fi
        if [[ -z "$MIRROR_REGION" ]]; then
          MIRROR_REGION="Worldwide"
          log "Mirror region defaulted to: $MIRROR_REGION"
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
# Timezone Configuration
# -------------------------
set_timezone() {
  local regions
  regions=$(find /usr/share/zoneinfo -maxdepth 1 -type d -name "[A-Z]*" | sed 's|.*/||' | sort)
  
  local region
  region=$(printf "%s" "$regions" | eval "$FZF --prompt=\"Region > \" --header=\"Choose timezone region\"") || return
  
  local cities
  cities=$(find "/usr/share/zoneinfo/$region" -type f | sed "s|.*/||" | sort)
  
  local city
  city=$(printf "%s" "$cities" | eval "$FZF --prompt=\"City > \" --header=\"Choose city in $region\"") || return
  
  TIMEZONE="$region/$city"
  log "Timezone set to: $TIMEZONE"
}

# -------------------------
# Locale Configuration
# -------------------------
set_locale() {
  local locales
  locales=$(grep -E "^#?[a-zA-Z]" /etc/locale.gen | sed 's/^#//' | awk '{print $1}' | sort | uniq)
  
  LOCALE=$(printf "%s" "$locales" | eval "$FZF --prompt=\"Locale > \" --header=\"Choose system locale\"") || return
  
  log "Locale set to: $LOCALE"
}

# -------------------------
# Mirror Region Configuration
# -------------------------
set_mirror_region() {
  local regions="Worldwide\nUnited States\nCanada\nMexico\nBrazil\nArgentina\nChile\nUnited Kingdom\nIreland\nGermany\nFrance\nItaly\nSpain\nPortugal\nNetherlands\nBelgium\nSwitzerland\nAustria\nSweden\nNorway\nDenmark\nFinland\nPoland\nCzech Republic\nHungary\nRomania\nBulgaria\nGreece\nTurkey\nRussia\nUkraine\nBelarusChina\nJapan\nSouth Korea\nTaiwan\nHong Kong\nSingapore\nMalaysia\nThailand\nVietnam\nIndonesia\nPhilippines\nIndia\nPakistan\nBangladesh\nSri Lanka\nNepal\nIran\nIsrael\nSaudi Arabia\nUAE\nEgypt\nSouth Africa\nKenya\nMorocco\nTunisia\nAustralia\nNew Zealand"
  
  echo "Current selection: ${MIRROR_REGION:-None}"
  echo "Select mirror regions (use Tab to select multiple, Enter to confirm):"
  echo
  
  local selected
  selected=$(printf "%s" "$regions" | eval "$FZF --multi --prompt=\"Mirrors > \" --header=\"Select one or more mirror regions (Tab=select, Enter=confirm)\"") || return
  
  # Convert newlines to comma-separated for storage
  MIRROR_REGION=$(echo "$selected" | tr '\n' ',')
  
  log "Mirror regions set to: $MIRROR_REGION"
}

# -------------------------
# Desktop Environment Step
# -------------------------
desktop_selection_step() {
  show_banner "Step: Desktop Environment"
  
  echo "Current selection: ${DESKTOP:-not set}"
  echo
  
  local choice
  choice=$(get_available_desktops | eval "$FZF --prompt=\"Desktop > \" --header=\"Choose desktop environment\"") || return 1
  
  DESKTOP="$choice"
  log "Desktop environment set to: $DESKTOP"
  
  return 0
}

# -------------------------
# Graphics Driver Step
# -------------------------
graphics_driver_step() {
  show_banner "Step: Graphics Driver"
  
  echo "Current selection: ${GRAPHICS_PACKAGES:-not set}"
  echo
  
  local driver
  driver=$(printf "Auto Detect\nNVIDIA (Proprietary)\nAMD (Open Source)\nIntel (Open Source)\nGeneric (VESA)\nSkip\nGo Back" | eval "$FZF --prompt=\"Graphics > \" --header=\"Choose graphics driver\"") || return 1
  
  case "$driver" in
    "Auto Detect")
      auto_detect_graphics
      ;;
    "Skip")
      GRAPHICS_PACKAGES=""
      log "Graphics driver selection skipped"
      ;;
    "Go Back")
      return 1
      ;;
    *)
      GRAPHICS_PACKAGES=$(get_graphics_packages "$driver")
      log "Graphics driver set to: $driver"
      ;;
  esac
  
  return 0
}

# -------------------------
# Audio Driver Step
# -------------------------
audio_driver_step() {
  show_banner "Step: Audio Driver"
  
  echo "Current selection: ${AUDIO_DRIVER:-PulseAudio (Default)}"
  echo
  
  AUDIO_DRIVER=$(printf "$(get_available_audio)\nGo Back" | eval "$FZF --prompt=\"Audio > \" --header=\"Choose audio system\"") || return 1
  
  case "$AUDIO_DRIVER" in
    "Go Back")
      return 1
      ;;
    *)
      log "Audio driver set to: $AUDIO_DRIVER"
      return 0
      ;;
  esac
}

# -------------------------
# Additional Packages Step
# -------------------------
additional_packages_step() {
  show_banner "Step: Additional Packages"
  
  if [[ -n "${ADDITIONAL_PACKAGES:-}" ]]; then
    local pkg_count=$(echo "$ADDITIONAL_PACKAGES" | wc -l)
    echo "Current selection: $pkg_count packages selected"
  else
    echo "Current selection: No additional packages"
  fi
  echo
  
  local choice
  choice=$(printf "Select Additional Packages\nClear Selection\nGo Back" | eval "$FZF --prompt=\"Packages > \" --header=\"Choose action\"") || return 1
  
  case "$choice" in
    "Select Additional Packages")
      select_additional_packages
      return 0
      ;;
    "Clear Selection")
      ADDITIONAL_PACKAGES=""
      log "Additional packages selection cleared"
      return 0
      ;;
    "Go Back")
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

# -------------------------
# Auto Detect Graphics
# -------------------------
auto_detect_graphics() {
  echo "Detecting graphics hardware..."
  
  if lspci | grep -i nvidia >/dev/null; then
    GRAPHICS_PACKAGES=$(get_graphics_packages "NVIDIA (Proprietary)")
    log "Auto-detected: NVIDIA graphics"
  elif lspci | grep -i amd >/dev/null; then
    GRAPHICS_PACKAGES=$(get_graphics_packages "AMD (Open Source)")
    log "Auto-detected: AMD graphics"
  elif lspci | grep -i intel >/dev/null; then
    GRAPHICS_PACKAGES=$(get_graphics_packages "Intel (Open Source)")
    log "Auto-detected: Intel graphics"
  else
    GRAPHICS_PACKAGES=$(get_graphics_packages "Generic (VESA)")
    log "Auto-detected: Generic VESA driver"
  fi
  
  echo "Detected graphics: $GRAPHICS_PACKAGES"
  read -rp "Press Enter to continue..."
}

# -------------------------
# Kernel Selection Step
# -------------------------
kernel_selection_step() {
  show_banner "Step: Kernel Selection"
  
  local kernel
  kernel=$(get_available_kernels | eval "$FZF --prompt=\"Kernel > \" --header=\"Select Linux kernel\"") || return 1
  
  KERNEL="$kernel"
  log "Selected kernel: $KERNEL"
  
  return 0
}

# -------------------------
# Network Manager Step
# -------------------------
network_manager_step() {
  show_banner "Step: Network Manager"
  
  local manager
  manager=$(get_available_network_managers | eval "$FZF --prompt=\"Network > \" --header=\"Select network manager\"") || return 1
  
  NETWORK_MANAGER="$manager"
  log "Selected network manager: $NETWORK_MANAGER"
  
  return 0
}

# -------------------------
# Display Manager Step
# -------------------------
display_manager_step() {
  show_banner "Step: Display Manager"
  
  local manager
  manager=$(get_available_display_managers | eval "$FZF --prompt=\"Display > \" --header=\"Select display manager\"") || return 1
  
  DISPLAY_MANAGER="$manager"
  log "Selected display manager: $DISPLAY_MANAGER"
  
  return 0
}

# -------------------------
# Power Manager Step
# -------------------------
power_manager_step() {
  show_banner "Step: Power Manager"
  
  local manager
  manager=$(get_available_power_managers | eval "$FZF --prompt=\"Power > \" --header=\"Select power manager\"") || return 1
  
  POWER_MANAGER="$manager"
  log "Selected power manager: $POWER_MANAGER"
  
  return 0
}
