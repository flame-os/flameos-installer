#!/usr/bin/env bash

name="Hyprland"
dotfiles=""

# Simple log function for chroot environment
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

install() {
  log "Installing $name desktop environment..."
  
  local packages=(
    hyprland waybar wofi dunst
    kitty thunar firefox
    grim slurp wl-clipboard
    brightnessctl pamixer
    polkit-gnome xdg-desktop-portal-hyprland
    xdg-desktop-portal-wlr
    git nano neovim
  )
  
  # Install packages
  pacman -S --noconfirm "${packages[@]}" || {
    log "Failed to install some Hyprland packages"
    return 1
  }
  
  # Create user config directories
  mkdir -p "/home/$USERNAME/.config"

  
  # Set proper ownership
  chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"
  
  # Clone dotfiles and setup
  git clone https://github.com/aislxflames/flamedots "/home/$USERNAME/flamedots"
  sed -i '$a exec-once = ~/setup-hyprland.sh' /home/$USERNAME/.config/hypr/hyprland.conf
  
cat <<'EOF' > /home/$USERNAME/setup-hyprland.sh
  #!/bin/bash
  kitty -e bash -c '
    if ping -c 1 google.com &> /dev/null; then
    echo "Internet connection is active."
  else
    nmtui
  fi
  # FlameDots setup
  ~/flamedots/build.sh
  '
  rm -rf ~/setup-hyprland.sh
EOF

  
  chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"
  chmod +x /home/$USERNAME/setup-hyprland.sh

  log "Hyprland installation completed"
}

# Run install function when script is executed
install
