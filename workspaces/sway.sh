#!/usr/bin/env bash

name="Sway"
dotfiles=""

install() {
  log "Installing $name window manager..."
  
  local packages=(
    sway waybar wofi
    kitty firefox thunar
    grim slurp wl-clipboard
  )
  
  pacman -S --noconfirm "${packages[@]}"
}
