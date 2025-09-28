#!/bin/bash
# AsiraOS - The Future of Linux
# Copyright (c) 2024 AsiraOS Team
# https://asiraos.github.io
# Licensed under GPL-3.0

set -euo pipefail

# AsiraOS System Configuration Script
# Configures OS branding, repositories, and GRUB theme

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

configure_asiraos_system() {
  local grub_theme_dir="${1:-}"
  
  log "Configuring AsiraOS system branding..."
  
  # Install reflector for mirror management
  pacman -S --noconfirm reflector
  
  # Create new os-release content
  cat > /etc/os-release << 'EOF'
NAME="AsiraOS"
PRETTY_NAME="AsiraOS"
ID=asiraos
BUILD_ID=rolling
ANSI_COLOR="38;2;220;50;47"
HOME_URL="https://github.com/asiraos"
SUPPORT_URL="https://github.com/asiraos"
BUG_REPORT_URL="https://github.com/asiraos"
LOGO=asiraos
IMAGE_ID=asiraos
IMAGE_VERSION=2025.05.11
EOF
  
  # Add AsiraOS pacman repository
  if ! grep -q "\[asiraos-core\]" /etc/pacman.conf; then
sed -i '/^\[core\]/i \
[asiraos-core]\nSigLevel = Optional TrustAll\nServer = https://asiraos.github.io/core/$arch\n' /etc/pacman.conf

  fi
  
  # Configure GRUB theme script
  cat > /etc/grub.d/05_debian_theme << 'EOF'
#!/bin/bash

# Check if /boot/efi is mounted separately for logo location
if mountpoint -q /boot/efi; then
    SHARED_LOGO="/boot/efi/grub/themes/shared/asiraos.png"
else
    SHARED_LOGO="/boot/grub/themes/shared/asiraos.png"
fi

# GRUB themes are always in /boot/grub/themes/
GRUB_THEMES_DIR="/boot/grub/themes"

if [[ ! -f "$SHARED_LOGO" ]]; then
    echo "Shared logo not found at $SHARED_LOGO"
    exit 1
fi

for theme_dir in ${GRUB_THEMES_DIR}/*/; do
    [[ "$theme_dir" == *"/shared/" ]] && continue
    mkdir -p "${theme_dir}icons"
    cp "$SHARED_LOGO" "${theme_dir}icons/asiraos.png"
done

echo "Logo copied to all GRUB themes."
EOF

  chmod +x /etc/grub.d/05_debian_theme
  
  # Update GRUB branding
  sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="AsiraOS"/' /etc/default/grub || \
    echo 'GRUB_DISTRIBUTOR="AsiraOS"' >> /etc/default/grub
  
  # Set GRUB theme if provided
  if [[ -n "$grub_theme_dir" ]]; then
    sed -i "s|^#*GRUB_THEME=.*|GRUB_THEME=\"$grub_theme_dir/theme.txt\"|" /etc/default/grub
  fi
  
  # Regenerate GRUB config
  grub-mkconfig -o /boot/grub/grub.cfg
  
  log "AsiraOS system configuration completed"
}

# Run the function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  configure_asiraos_system "$@"
fi
