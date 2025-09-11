#!/usr/bin/env bash

name="KDE Plasma"
dotfiles="KDE-Flame"

install() {
  log "Installing $name desktop environment..."
  
  local packages=(
    plasma-meta kde-applications-meta
    sddm sddm-kcm
  )
  
  pacman -S --noconfirm "${packages[@]}"
  systemctl enable sddm
  
  if [[ -n "$dotfiles" ]]; then
    log "Installing $dotfiles configuration..."
    # Clone and install dotfiles here
  fi
}
