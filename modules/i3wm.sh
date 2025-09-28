#!/bin/bash
# FlameOS - The Future of Linux
# Copyright (c) 2024 FlameOS Team
# https://flame-os.github.io
# Licensed under GPL-3.0


# i3wm Desktop Environment Installation
echo "Installing i3wm Desktop Environment..."

pacman -S --noconfirm --needed i3-wm i3status i3lock dmenu xorg-server xorg-xinit lightdm lightdm-gtk-greeter
systemctl enable lightdm

echo "i3wm installation completed"
