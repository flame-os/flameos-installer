#!/usr/bin/env bash
set -euo pipefail

# FlameOS System Configuration Script
# Configures OS branding, repositories, and GRUB theme

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

configure_flameos_system() {
  local grub_theme_dir="${1:-}"
  
  log "Configuring FlameOS system branding..."
  
  # Install reflector for mirror management
  pacman -S --noconfirm reflector
  
  # Configure mirrors based on region
  if [[ -n "${MIRROR_REGION:-}" && "$MIRROR_REGION" != "Worldwide" ]]; then
    log "Configuring mirrors for regions: $MIRROR_REGION"
    
    # Convert comma-separated regions to reflector format
    local countries="${MIRROR_REGION//,/ }"
    
    # Remove "Worldwide" if it's in the list
    countries="${countries//Worldwide/}"
    countries="${countries## }"  # Remove leading spaces
    countries="${countries%% }"  # Remove trailing spaces
    
    if [[ -n "$countries" ]]; then
      reflector --country "$countries" --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    else
      reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    fi
  else
    log "Using worldwide mirrors"
    reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  fi
  
  # Create new os-release content
  cat > /etc/os-release << 'EOF'
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
  
  # Add FlameOS pacman repository
  if ! grep -q "\[flameos-core\]" /etc/pacman.conf; then
    cat >> /etc/pacman.conf << 'EOF'

[flameos-core]
SigLevel = Optional DatabaseOptional
Server = https://flame-os.github.io/core/$arch
EOF
  fi
  
  # Configure GRUB theme script
  cat > /etc/grub.d/05_debian_theme << 'EOF'
#!/bin/bash

SHARED_LOGO="/boot/grub/themes/shared/flameos.png"

if [[ ! -f "$SHARED_LOGO" ]]; then
    echo "Shared logo not found at $SHARED_LOGO"
    exit 1
fi

for theme_dir in /boot/grub/themes/*/; do
    [[ "$theme_dir" == *"/shared/" ]] && continue
    mkdir -p "${theme_dir}icons"
    cp "$SHARED_LOGO" "${theme_dir}icons/flameos.png"
done

echo "Logo copied to all GRUB themes."
EOF

  chmod +x /etc/grub.d/05_debian_theme
  
  # Update GRUB branding
  sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="FlameOS"/' /etc/default/grub || \
    echo 'GRUB_DISTRIBUTOR="FlameOS"' >> /etc/default/grub
  
  # Set GRUB theme if provided
  if [[ -n "$grub_theme_dir" ]]; then
    sed -i "s|^#*GRUB_THEME=.*|GRUB_THEME=\"$grub_theme_dir/theme.txt\"|" /etc/default/grub
  fi
  
  # Regenerate GRUB config
  grub-mkconfig -o /boot/grub/grub.cfg
  
  log "FlameOS system configuration completed"
}

# Run the function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  configure_flameos_system "$@"
fi
