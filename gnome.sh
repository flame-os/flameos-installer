#!/bin/bash

# Ensure the username is passed as the first argument
username="$1"

if [ -z "$username" ]; then
    echo "Error: Username is required!"
    exit 1
fi

USER_HOME="/home/$username"

sudo pacman -S gnome gnome-extra sddm bluez --needed
sudo systemctl enable sddm
sudo systemctl enable bluetooth

