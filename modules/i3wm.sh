#!/bin/bash


# i3wm Desktop Environment Installation
echo "Installing i3wm Desktop Environment..."

pacman -S --noconfirm --needed i3-wm i3status i3lock dmenu xorg-server xorg-xinit lightdm lightdm-gtk-greeter
systemctl enable lightdm

echo "i3wm installation completed"
