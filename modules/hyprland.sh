#!/bin/bash
# FlameOS - The Future of Linux
# Copyright (c) 2024 FlameOS Team
# https://flame-os.github.io
# Licensed under GPL-3.0


# Hyprland Desktop Environment Installation
echo "Installing Hyprland Desktop Environment..."

pacman -S --noconfirm --needed hyprland waybar wofi kitty sddm
systemctl enable sddm

echo "Hyprland installation completed"
