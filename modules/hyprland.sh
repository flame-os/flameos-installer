#!/bin/bash

# Hyprland Desktop Environment Installation
echo "Installing Hyprland Desktop Environment..."

pacman -S --noconfirm --needed hyprland waybar wofi kitty sddm
systemctl enable sddm

echo "Hyprland installation completed"
