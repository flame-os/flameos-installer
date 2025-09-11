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
  )
  
  # Install packages
  pacman -S --noconfirm "${packages[@]}" || {
    log "Failed to install some Hyprland packages"
    return 1
  }
  
  # Create user config directories
  mkdir -p "/home/$USERNAME/.config"
  
  if [[ -n "$dotfiles" ]]; then
    log "Installing $dotfiles configuration..."
    # Create basic Hyprland config if dotfiles repo not available
    mkdir -p "/home/$USERNAME/.config/hypr"
    cat > "/home/$USERNAME/.config/hypr/hyprland.conf" <<EOF
# FlameOS Hyprland Configuration
monitor=,preferred,auto,auto

exec-once = waybar
exec-once = dunst

input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = no
    }
    sensitivity = 0
}

general {
    gaps_in = 5
    gaps_out = 20
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

decoration {
    rounding = 10
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    drop_shadow = yes
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

bind = SUPER, Q, exec, kitty
bind = SUPER, C, killactive,
bind = SUPER, M, exit,
bind = SUPER, E, exec, thunar
bind = SUPER, V, togglefloating,
bind = SUPER, R, exec, wofi --show drun
bind = SUPER, P, pseudo,
bind = SUPER, J, togglesplit,

bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d

bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5

bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5
EOF
  fi
  
  # Set proper ownership
  chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"
  
  log "Hyprland installation completed"
}
