#!/usr/bin/env bash

name="GNOME"
dotfiles="Gnome-Flame"

install() {
  log "Installing $name desktop environment..."
  
  local packages=(
    gnome gnome-extra
    gdm
  )
  
  pacman -S --noconfirm "${packages[@]}"
  systemctl enable gdm
  
  if [[ -n "$dotfiles" ]]; then
    log "Installing $dotfiles configuration..."
    # Clone and install dotfiles here
  fi
}
