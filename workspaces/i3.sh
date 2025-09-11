#!/usr/bin/env bash

name="i3"
dotfiles=""

install() {
  log "Installing $name window manager..."
  
  local packages=(
    i3-wm i3status i3lock dmenu
    xorg-server xorg-xinit
    lightdm lightdm-gtk-greeter
    kitty firefox thunar
  )
  
  pacman -S --noconfirm "${packages[@]}"
  systemctl enable lightdm
}
