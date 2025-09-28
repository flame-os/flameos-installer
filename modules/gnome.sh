#!/bin/bash
# FlameOS - The Future of Linux
# Copyright (c) 2024 FlameOS Team
# https://flame-os.github.io
# Licensed under GPL-3.0


# GNOME Desktop Environment Installation
echo "Installing GNOME Desktop Environment..."

pacman -S --noconfirm --needed gnome gnome-extra gdm
systemctl enable gdm

echo "GNOME installation completed"
