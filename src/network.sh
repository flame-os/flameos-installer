#!/usr/bin/env bash

# FlameOS Installer - Network Configuration
# Network setup and connectivity

# -------------------------
# Network Setup Step
# -------------------------
network_setup_step() {
  show_banner "Step: Network Setup"
  
  # Check if internet is available
  if ping -c 1 8.8.8.8 &>/dev/null || ping -c 1 1.1.1.1 &>/dev/null; then
    log "Internet connection detected"
    echo "✓ Internet connection available"
    sleep 1
    return 0
  fi
  
  # No internet - open nmtui for configuration
  echo "No internet connection detected. Opening network configuration..."
  sleep 1
  nmtui
  
  # Check again after nmtui
  if ping -c 1 8.8.8.8 &>/dev/null || ping -c 1 1.1.1.1 &>/dev/null; then
    log "Network configured successfully"
    echo "✓ Network configured successfully"
    sleep 1
    return 0
  else
    echo "⚠ Network configuration may not be complete"
    local choice
    choice=$(printf "Continue anyway\nTry again\nGo Back" | eval "$FZF --prompt=\"Network > \" --header=\"No internet detected\"") || return 1
    
    case "$choice" in
      "Continue anyway")
        return 0
        ;;
      "Try again")
        network_setup_step
        ;;
      "Go Back")
        return 1
        ;;
    esac
  fi
}

# -------------------------
# WiFi Configuration
# -------------------------
configure_wifi() {
  show_banner "WiFi Configuration"
  
  echo "Scanning for WiFi networks..."
  iwctl station wlan0 scan 2>/dev/null || {
    echo "WiFi adapter not found or not available"
    read -rp "Press Enter to continue..."
    return 1
  }
  
  sleep 3
  local networks
  networks=$(iwctl station wlan0 get-networks 2>/dev/null | tail -n +5 | awk '{print $1}' | grep -v "^$" | head -20)
  
  if [[ -z "$networks" ]]; then
    echo "No WiFi networks found"
    read -rp "Press Enter to continue..."
    return 1
  fi
  
  local ssid
  ssid=$(printf "%s\nManual Entry\nGo Back" "$networks" | eval "$FZF --prompt=\"WiFi Network > \" --header=\"Choose WiFi network\"") || return 1
  
  case "$ssid" in
    "Manual Entry")
      read -rp "Enter SSID: " ssid
      ;;
    "Go Back")
      return 1
      ;;
  esac
  
  if [[ -z "$ssid" ]]; then
    echo "No SSID entered"
    return 1
  fi
  
  read -rsp "Enter password for $ssid: " password
  echo
  
  echo "Connecting to $ssid..."
  iwctl station wlan0 connect "$ssid" --passphrase "$password" || {
    echo "Failed to connect to WiFi"
    read -rp "Press Enter to continue..."
    return 1
  }
  
  echo "WiFi connected successfully!"
  read -rp "Press Enter to continue..."
  return 0
}

# -------------------------
# Ethernet Configuration
# -------------------------
configure_ethernet() {
  show_banner "Ethernet Configuration"
  
  echo "Checking ethernet connection..."
  
  # Try to bring up ethernet interface
  local eth_interface
  eth_interface=$(ip link show | grep -E "^[0-9]+: (eth|enp)" | head -n1 | cut -d: -f2 | tr -d ' ')
  
  if [[ -z "$eth_interface" ]]; then
    echo "No ethernet interface found"
    read -rp "Press Enter to continue..."
    return 1
  fi
  
  ip link set "$eth_interface" up
  
  local choice
  choice=$(printf "DHCP (Automatic)\nStatic IP\nGo Back" | eval "$FZF --prompt=\"Ethernet Config > \" --header=\"Choose ethernet configuration\"") || return 1
  
  case "$choice" in
    "DHCP (Automatic)")
      echo "Requesting IP via DHCP..."
      dhcpcd "$eth_interface" || {
        echo "DHCP failed"
        read -rp "Press Enter to continue..."
        return 1
      }
      ;;
    "Static IP")
      configure_static_ip "$eth_interface"
      ;;
    "Go Back")
      return 1
      ;;
  esac
  
  echo "Ethernet configured successfully!"
  read -rp "Press Enter to continue..."
  return 0
}

# -------------------------
# Static IP Configuration
# -------------------------
configure_static_ip() {
  local interface="$1"
  
  read -rp "Enter IP address (e.g., 192.168.1.100): " ip_addr
  read -rp "Enter subnet mask (e.g., 24): " subnet
  read -rp "Enter gateway (e.g., 192.168.1.1): " gateway
  read -rp "Enter DNS server (e.g., 8.8.8.8): " dns
  
  if [[ -z "$ip_addr" || -z "$subnet" || -z "$gateway" ]]; then
    echo "Missing required network information"
    return 1
  fi
  
  # Configure static IP
  ip addr add "$ip_addr/$subnet" dev "$interface"
  ip route add default via "$gateway"
  
  if [[ -n "$dns" ]]; then
    echo "nameserver $dns" > /etc/resolv.conf
  fi
  
  return 0
}
