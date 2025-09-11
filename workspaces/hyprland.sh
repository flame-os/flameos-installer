#!/usr/bin/env bash

name="Hyprland"
dotfiles="Flamedots"

install() {
  log "Installing $name desktop environment..."
  
  local packages=(
    hyprland waybar wofi dunst
    kitty thunar firefox
    grim slurp wl-clipboard
    brightnessctl pamixer
    polkit-gnome xdg-desktop-portal-hyprland
    xdg-desktop-portal-wlr
    sddm
    bluez bluez-utils
    networkmanager network-manager-applet
    git
    neovim
    nano
  )
  
  # Install packages
  pacman -S --noconfirm "${packages[@]}" || {
    log "Failed to install some Hyprland packages"
    return 1
  }
  
  # Create user config directories
  mkdir -p "/home/$USERNAME/.config"
  
  # Install dotfiles if available
  if [[ -n "$dotfiles" && -d "/tmp/dotfiles/$dotfiles" ]]; then
    log "Installing $dotfiles configuration..."
    cp -r "/tmp/dotfiles/$dotfiles/"* "/home/$USERNAME/.config/"
  else
    log "Dotfiles not found, creating basic config..."
    mkdir -p "/home/$USERNAME/.config/hypr"
    cat > "/home/$USERNAME/.config/hypr/hyprland.conf" <<EOF
monitor=,preferred,auto,auto
exec-once = waybar
exec-once = dunst
input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
}
general {
    gaps_in = 5
    gaps_out = 20
    border_size = 2
    col.active_border = rgba(33ccffee)
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}
bind = SUPER, Q, exec, kitty
bind = SUPER, C, killactive,
bind = SUPER, E, exec, thunar
bind = SUPER, R, exec, wofi --show drun
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
EOF
  fi
  
  # Set proper ownership
  chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"
  
  # Enable Systemd services
  systemctl enable sddm
  systemctl enable NetworkManager
  systemctl enable bluetooth

  log "Hyprland installation completed"
}
