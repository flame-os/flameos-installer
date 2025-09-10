#!/usr/bin/env bash

# FlameOS Installer - Desktop Environment Configurations
# Consolidated desktop environment installation scripts

install_hyprland() {
  log "Installing Hyprland desktop environment..."
  
  local packages=(
    hyprland waybar wofi dunst
    kitty thunar firefox
    grim slurp wl-clipboard
    brightnessctl pamixer
    polkit-gnome xdg-desktop-portal-hyprland
  )
  
  pacman -S --noconfirm "${packages[@]}"
  
  # Basic Hyprland config
  mkdir -p /home/"$USERNAME"/.config/hypr
  cat > /home/"$USERNAME"/.config/hypr/hyprland.conf << 'EOF'
monitor=,preferred,auto,auto
exec-once = waybar & dunst
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = no
    }
}
general {
    gaps_in = 5
    gaps_out = 20
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
}
decoration {
    rounding = 10
}
$mainMod = SUPER
bind = $mainMod, Q, exec, kitty
bind = $mainMod, C, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, thunar
bind = $mainMod, V, togglefloating,
bind = $mainMod, R, exec, wofi --show drun
EOF
  
  chown -R "$USERNAME:$USERNAME" /home/"$USERNAME"/.config
}

install_kde() {
  log "Installing KDE Plasma desktop environment..."
  
  local packages=(
    plasma-meta kde-applications-meta
    sddm sddm-kcm
  )
  
  pacman -S --noconfirm "${packages[@]}"
  systemctl enable sddm
}

install_gnome() {
  log "Installing GNOME desktop environment..."
  
  local packages=(
    gnome gnome-extra
    gdm
  )
  
  pacman -S --noconfirm "${packages[@]}"
  systemctl enable gdm
}

install_xfce() {
  log "Installing XFCE desktop environment..."
  
  local packages=(
    xfce4 xfce4-goodies
    lightdm lightdm-gtk-greeter
  )
  
  pacman -S --noconfirm "${packages[@]}"
  systemctl enable lightdm
}

install_i3() {
  log "Installing i3 window manager..."
  
  local packages=(
    i3-wm i3status i3lock dmenu
    xorg-server xorg-xinit
    lightdm lightdm-gtk-greeter
    kitty firefox thunar
  )
  
  pacman -S --noconfirm "${packages[@]}"
  systemctl enable lightdm
}

install_sway() {
  log "Installing Sway window manager..."
  
  local packages=(
    sway waybar wofi
    kitty firefox thunar
    grim slurp wl-clipboard
  )
  
  pacman -S --noconfirm "${packages[@]}"
}

install_desktop_by_name() {
  local desktop="$1"
  
  case "$desktop" in
    "Hyprland")
      install_hyprland
      ;;
    "KDE Plasma")
      install_kde
      ;;
    "GNOME")
      install_gnome
      ;;
    "XFCE")
      install_xfce
      ;;
    "i3")
      install_i3
      ;;
    "Sway")
      install_sway
      ;;
    "Minimal")
      log "Minimal installation - no desktop environment"
      ;;
    *)
      log "Unknown desktop environment: $desktop"
      return 1
      ;;
  esac
}
