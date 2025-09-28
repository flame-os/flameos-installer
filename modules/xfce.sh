#!/bin/bash
# FlameOS - The Future of Linux
# Copyright (c) 2024 FlameOS Team
# https://flame-os.github.io
# Licensed under GPL-3.0


# XFCE Desktop Environment Installation
echo "Installing XFCE Desktop Environment..."

pacman -S --noconfirm --needed xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
systemctl enable lightdm

echo "XFCE installation completed"
