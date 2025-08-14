#!/bin/bash

# Ensure the username is passed as the first argument
username="$1"

if [ -z "$username" ]; then
    echo "Error: Username is required!"
    exit 1
fi

USER_HOME="/home/$username"
SOURCE_CONFIG="./dotfiles/"
SOURCE_WALLPAPERS="./wallpapers"

# Ensure correct permissions for the user home directory
sudo chown -R "$username:$username" "$USER_HOME"
sudo chown -R "$username:$username" /opt

sudo pacman -S hyprland kitty wofi sddm xdg-desktop-portal-hyprland pipewire wireplumber bluez --noconfirm
sudo systemctl enable sddm
sudo systemctl enable bluetooth

# Using su -c to run the commands as the user
git clone https://github.com/aislxflames/flamedots /home/$username/flamedots


cat <<EOF > desktop.sh
cd ~/flamedots
kitty -e bash -c 'nmtui && ~/flamedots/build.sh'
sleep 1
rm -rf desktop.sh
EOF

cp -r .bashrc /home/$username
mv desktop.sh /home/$username
chown -R $username:$username /home/$username/desktop.sh
chmod +x /home/$username/desktop.sh
