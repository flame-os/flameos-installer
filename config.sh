#!/bin/bash
set -e

# Create os-release in /tmp
cat <<EOF > /tmp/os-release
NAME="FlameOS"
PRETTY_NAME="FlameOS"
ID=flameos
BUILD_ID=rolling
ANSI_COLOR="38;2;220;50;47"
HOME_URL="https://github.com/flame-os"
SUPPORT_URL="https://github.com/flame-os"
BUG_REPORT_URL="https://github.com/flame-os"
LOGO=flameos

IMAGE_ID=flameos
IMAGE_VERSION=2025.05.11
EOF

# Replace system os-release
sudo rm -f /etc/os-release
sudo cp /tmp/os-release /etc/os-release

# --- Add FlameOS pacman repo ---
if ! grep -q "\[flameos-core\]" /etc/pacman.conf; then
    echo -e "\n[flameos-core]\nSigLevel = Optional DatabaseOptional\nServer = https://flame-os.github.io/core/\$arch" | sudo tee -a /etc/pacman.conf > /dev/null
fi

cat <<EOF > /etc/grub.d/05_debian_theme
#!/bin/bash

# Path to your shared logo
SHARED_LOGO="/boot/grub/themes/shared/flameos.png"

# Ensure shared logo exists
if [[ ! -f "$SHARED_LOGO" ]]; then
    echo "Shared logo not found at $SHARED_LOGO"
    exit 1
fi

# Loop through all theme folders
for theme_dir in /boot/grub/themes/*/; do
    # Skip the 'shared' folder
    [[ "$theme_dir" == *"/shared/" ]] && continue

    # Make icons folder if missing
    mkdir -p "${theme_dir}icons"

    # Copy logo
    cp "$SHARED_LOGO" "${theme_dir}icons/flameos.png"

    echo "Copied logo to ${theme_dir}icons/"
done

echo "🎯 Logo copied to all GRUB themes."

EOF

sudo chmod +x /etc/grub.d/05_debian_theme

# --- Update GRUB branding ---
sudo sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="FlameOS"/' /etc/default/grub || \
echo 'GRUB_DISTRIBUTOR="FlameOS"' | sudo tee -a /etc/default/grub > /dev/null

# Ensure GRUB_THEME is set
if [ -n "$GRUB_THEME_DIR" ]; then
    sudo sed -i "s|^#*GRUB_THEME=.*|GRUB_THEME=\"$GRUB_THEME_DIR/theme.txt\"|" /etc/default/grub
fi

# --- Regenerate GRUB config ---
if [ -d /sys/firmware/efi ]; then
    sudo grub-mkconfig -o /boot/grub/grub.cfg
else
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "FlameOS core applied to os-release, pacman.conf, and GRUB theme/logo."
