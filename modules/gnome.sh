#!/bin/bash

# GNOME Desktop Environment Installation
echo "Installing GNOME Desktop Environment..."

pacman -S --noconfirm --needed gnome gnome-extra gdm
systemctl enable gdm

echo "GNOME installation completed"
