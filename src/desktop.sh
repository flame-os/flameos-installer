#!/usr/bin/env bash

# FlameOS Installer - Desktop Environment Manager
# Modular desktop environment installation system

get_available_desktops() {
  local desktop_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/workspaces"
  local desktops=()
  
  for script in "$desktop_dir"/*.sh; do
    if [[ -f "$script" ]]; then
      local name=""
      source "$script"
      [[ -n "$name" ]] && desktops+=("$name")
    fi
  done
  
  printf "%s\n" "${desktops[@]}"
}

install_desktop_by_name() {
  local desktop="$1"
  local desktop_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/workspaces"
  
  # Find and source the matching desktop script
  for script in "$desktop_dir"/*.sh; do
    if [[ -f "$script" ]]; then
      local name=""
      source "$script"
      if [[ "$name" == "$desktop" ]]; then
        install
        return 0
      fi
    fi
  done
  
  log "Unknown desktop environment: $desktop"
  return 1
}
