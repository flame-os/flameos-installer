#!/bin/bash
set -e

echo "Starting FlameOS dotfiles auto-installation..."

# Update system and install dependencies
sudo pacman -Syu lolcat fzf --noconfirm

USER_HOME="/home/$(logname)"

# Install yay
sudo chown -R $(logname):$(logname) /home/$(logname)
sudo chown -R $(logname):$(logname) /opt
sudo rm -rf /opt/yay
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git /opt/yay
    sudo chown -R $(logname):$(logname) /opt/yay
    cd /opt/yay && makepkg -si --noconfirm
fi

# Install packages
if [ -f "./packages.sh" ]; then
    mapfile -t packages < <(grep -vE '^\s*#|^\s*$' ./packages.sh | tr -d '\r')
    for pkg in "${packages[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            yay -S --noconfirm "$pkg"
        fi
    done
fi

# Copy dotfiles
if [ -d "./dotfiles/" ]; then
    rsync -avi "./dotfiles/" "$USER_HOME/"
fi

# Install grub theme
if [ -d "rootfiles/grub/Castorice" ]; then
    sudo mkdir -p /boot/grub/themes/
    sudo cp -rf rootfiles/grub/Castorice /boot/grub/themes/Castorice
    sudo sed -i '/^GRUB_THEME=/d' /etc/default/grub
    echo 'GRUB_THEME="/boot/grub/themes/Castorice/theme.txt"' | sudo tee -a /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

# Install sddm theme
if [ -d "rootfiles/sddm/Candy" ]; then
    sudo cp -rf rootfiles/sddm/Candy /usr/share/sddm/themes/Candy
    sudo mkdir -p /etc
    echo -e '[Theme]\nCurrent=Candy' | sudo tee /etc/sddm.conf
fi

# Setup zsh
sudo rm -rf ~/.oh-my-zsh
CHSH=no RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
chsh -s $(which zsh)

if [ -f "./dotfiles/.zshrc" ]; then
    cp -rf ./dotfiles/.zshrc $USER_HOME/.zshrc
fi
if [ -f "./dotfiles/.p10k.zsh" ]; then
    cp -rf ./dotfiles/.p10k.zsh $USER_HOME/.p10k.zsh
fi

# Copy environment files
if [ -f "rootfiles/environment" ]; then
    sudo cp -r rootfiles/environment /etc/environment
fi

# Enable services
sudo systemctl enable sddm
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth

echo "FlameOS dotfiles installation completed!"
echo "Reboot to apply all changes."
