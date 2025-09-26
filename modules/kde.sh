#!/bin/bash

# KDE Plasma Desktop Environment Installation
echo "Installing KDE Plasma Desktop Environment..."

pacman -S --noconfirm --needed plasma plasma-wayland-session kde-applications sddm
systemctl enable sddm

echo "KDE Plasma installation completed"
