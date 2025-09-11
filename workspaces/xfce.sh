#!/usr/bin/env bash

name="XFCE"
dotfiles=""

install() {
  log "Installing $name desktop environment..."
  
  local packages=(
    xfce4 xfce4-goodies
    lightdm lightdm-gtk-greeter
  )
  
  pacman -S --noconfirm "${packages[@]}"
  systemctl enable lightdm
}
