#!/usr/bin/env bash

# FlameOS Installer - User Interface
# Banner, menus, and UI functions

# -------------------------
# Banner Display
# -------------------------
show_banner() {
  local title="${1:-}"
  if $CLEAR_ON_SHOW; then clear; fi
  
  # Get current terminal width (recalculate each time)
  local width=$(tput cols 2>/dev/null || echo 80)
  local banner_width=42  # Actual width of the ASCII art
  local padding=$(( (width - banner_width) / 2 ))
  
  # Ensure padding is not negative
  if [[ $padding -lt 0 ]]; then
    padding=0
  fi
  
  # Print each line of banner centered
  printf "%*s▗▄▄▄▖▗▖    ▗▄▖ ▗▖  ▗▖▗▄▄▄▖     ▗▄▖  ▗▄▄▖\n" $padding ""
  printf "%*s▐▌   ▐▌   ▐▌ ▐▌▐▛▚▞▜▌▐▌       ▐▌ ▐▌▐▌   \n" $padding ""
  printf "%*s▐▛▀▀▘▐▌   ▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘    ▐▌ ▐▌ ▝▀▚▖\n" $padding ""
  printf "%*s▐▌   ▐▙▄▄▖▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖    ▝▚▄▞▘▗▄▄▞▘\n" $padding ""
  
  if [[ -n "$title" ]]; then
    local title_text="=== $title ==="
    local title_padding=$(( (width - ${#title_text}) / 2 ))
    printf "\n%*s%s\n\n" $title_padding "" "$title_text"
  else
    echo
  fi
}

# -------------------------
# Installation Flows
# -------------------------
guided_installation() {
  show_banner "Guided Installation"
  
  local step=1
  
  # Step-by-step installation with proper back navigation
  while true; do
    case $step in
      1) # Network
        if network_setup_step; then
          step=2
        else
          step=1  # Stay on network step
        fi
        ;;
      2) # Mirror Region
        if mirror_selection_step; then
          step=3
        else
          step=1  # Go back to network
        fi
        ;;
      3) # Disk & Partitions
        if select_disk_step; then
          step=4
        else
          step=2  # Go back to mirror
        fi
        ;;
      4) # User Configuration
        if user_config_step; then
          step=5
        else
          step=3  # Go back to disk
        fi
        ;;
      5) # System Configuration
        if system_config_step; then
          step=6
        else
          step=4  # Go back to user config
        fi
        ;;
      6) # Desktop Environment
        if desktop_selection_step; then
          step=7
        else
          step=5  # Go back to system config
        fi
        ;;
      7) # Graphics Driver
        if graphics_driver_step; then
          step=8
        else
          step=6  # Go back to desktop selection
        fi
        ;;
      8) # Audio Driver
        if audio_driver_step; then
          step=9
        else
          step=7  # Go back to graphics driver
        fi
        ;;
      9) # Summary & Install
        if summary_and_install_flow; then
          break  # Installation complete
        else
          step=8  # Go back to audio driver
        fi
        ;;
      *) # Exit to main menu
        return 0
        ;;
    esac
  done
}

advanced_mode() {
  show_banner "Advanced Mode"
  
  while true; do
    local choice
    choice=$(printf "Network Setup\nMirror Region\nDisk Management\nUser Configuration\nSystem Configuration\nDesktop Environment\nGraphics Driver\nAudio Driver\nSummary and Install\nExit to Main Menu" | eval "$FZF --prompt=\"Advanced > \" --header=\"Choose configuration step\"") || return 0
    
    case "$choice" in
      "Network Setup") network_setup_step || true ;;
      "Mirror Region") mirror_selection_step || true ;;
      "Disk Management") select_disk_step || true ;;
      "User Configuration") user_config_step || true ;;
      "System Configuration") system_config_step || true ;;
      "Desktop Environment") desktop_selection_step || true ;;
      "Graphics Driver") graphics_driver_step || true ;;
      "Audio Driver") audio_driver_step || true ;;
      "Summary and Install") summary_and_install_flow || true ;;
      "Exit to Main Menu") return 0 ;;
      *) return 0 ;;
    esac
  done
}
