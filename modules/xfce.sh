#!/bin/bash


# XFCE Desktop Environment Installation
echo "Installing XFCE Desktop Environment..."

pacman -S --noconfirm --needed xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
systemctl enable lightdm

echo "XFCE installation completed"
