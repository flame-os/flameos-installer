#!/bin/bash
# FlameOS - The Future of Linux
# Copyright (c) 2024 FlameOS Team
# https://flame-os.github.io
# Licensed under GPL-3.0


# KDE Plasma Desktop Environment Installation
echo "Installing KDE Plasma Desktop Environment..."

pacman -S --noconfirm --needed plasma plasma-wayland-session kde-applications sddm
systemctl enable sddm

echo "KDE Plasma installation completed"
