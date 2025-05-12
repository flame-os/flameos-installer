sudo cat <<EOF > /mnt/etc/os-release
NAME="Flame OS"
PRETTY_NAME="Flame OS"
ID=flameos
BUILD_ID=rolling
ANSI_COLOR="38;2;220;50;47"
HOME_URL="https://github.com/theflames-presence/flameos"
SUPPORT_URL="https://github.com/theflames-presence/flameos"
BUG_REPORT_URL="https://github.com/theflames-presence/flameos"
LOGO=flameos

IMAGE_ID=flameos
IMAGE_VERSION=2025.05.11
EOF

echo -e "\n[flameos-repo]\nSigLevel = Optional DatabaseOptional\nServer = https://theflames-presence.github.io/flameos-repo/\$arch" | sudo tee -a /mnt/etc/pacman.conf > /dev/null
