#!/bin/bash
set -e

echo "Installing Flamedots for user: $USERNAME"

USER_HOME="/home/$USERNAME"

# Install yay if not present
if ! command -v yay &> /dev/null; then
    echo "Installing yay..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    sudo -u $USERNAME makepkg -si --noconfirm
    rm -rf /tmp/yay
fi

# Install packages from packages.sh if it exists
if [ -f "./packages.sh" ]; then
    echo "Installing packages..."
    mapfile -t packages < <(grep -vE '^\s*#|^\s*$' ./packages.sh | tr -d '\r')
    for pkg in "${packages[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            sudo -u $USERNAME yay -S --noconfirm "$pkg"
        fi
    done
fi

# Install GRUB theme if available
if [ -d "./rootfiles/grub" ]; then
    echo "Installing GRUB theme..."
    mkdir -p /boot/grub/themes/
    cp -rf ./rootfiles/grub/* /boot/grub/themes/
    sed -i '/^GRUB_THEME=/d' /etc/default/grub
    echo 'GRUB_THEME="/boot/grub/themes/Castorice/theme.txt"' >> /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
fi

# Install SDDM theme if available
if [ -d "./rootfiles/sddm" ]; then
    echo "Installing SDDM theme..."
    cp -rf ./rootfiles/sddm/* /usr/share/sddm/themes/
    echo -e '[Theme]\nCurrent=Candy' > /etc/sddm.conf
fi

# Setup zsh with oh-my-zsh and powerlevel10k
echo "Setting up zsh..."
sudo -u $USERNAME bash -c '
    rm -rf ~/.oh-my-zsh
    CHSH=no RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
'
chsh -s $(which zsh) $USERNAME

# Copy environment files if available
if [ -f "./rootfiles/environment" ]; then
    cp ./rootfiles/environment /etc/environment
fi

# Set proper ownership of all user files
chown -R $USERNAME:$USERNAME $USER_HOME

echo "Flamedots installation completed for $USERNAME!"
