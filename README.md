# FlameOS Installer

A professional, modular installer for FlameOS - an Arch Linux-based distribution.

## Features

- **Guided Installation**: Step-by-step installation process for beginners
- **Advanced Mode**: Flexible configuration for experienced users
- **Multiple Desktop Environments**: Hyprland, KDE Plasma, GNOME, XFCE, i3, Sway, or Minimal
- **Automatic Graphics Driver Detection**: NVIDIA, AMD, Intel support
- **Disk Management**: Auto-partitioning or manual partition management
- **Network Configuration**: WiFi and Ethernet setup
- **User-Friendly Interface**: Interactive menus using fzf

## Requirements

- Arch Linux live environment
- Root privileges
- Internet connection
- `fzf` package installed

## Installation

1. Boot into Arch Linux live environment
2. Clone or download this installer
3. Run as root:
   ```bash
   sudo ./install.sh
   ```

## Project Structure

```
flameos-installer/
├── install.sh              # Main entry point
├── system-config.sh         # FlameOS system configuration
├── src/
│   ├── config.sh           # Global configuration and variables
│   ├── ui.sh               # User interface and menu flows
│   ├── disk.sh             # Disk selection and management
│   ├── partition.sh        # Partitioning operations
│   ├── install.sh          # Installation procedures
│   ├── network.sh          # Network configuration
│   ├── user.sh             # User and system configuration
│   └── desktop.sh          # Desktop environment installations
└── README.md               # This file
```

## Usage

### Guided Installation
1. Select "Guided Installation" from the main menu
2. Follow the step-by-step process:
   - Network setup
   - Disk selection and partitioning
   - User configuration
   - System settings
   - Desktop environment selection
   - Graphics driver selection
   - Installation confirmation

### Advanced Mode
Access individual configuration steps in any order:
- Network Setup
- Disk Management
- User Configuration
- System Configuration
- Desktop Environment
- Graphics Driver
- Summary and Install

## Supported Desktop Environments

- **Hyprland**: Modern Wayland compositor with tiling
- **KDE Plasma**: Full-featured desktop environment
- **GNOME**: Modern desktop with Wayland support
- **XFCE**: Lightweight and customizable
- **i3**: Tiling window manager for X11
- **Sway**: i3-compatible Wayland compositor
- **Minimal**: No desktop environment (server/custom setup)

## Graphics Drivers

- **Auto Detect**: Automatically detect and install appropriate drivers
- **NVIDIA**: Proprietary NVIDIA drivers
- **AMD**: Open source AMDGPU drivers
- **Intel**: Open source Intel graphics drivers
- **Generic**: VESA fallback drivers

## Logging

Installation logs are saved to `/tmp/flameos-install.log` for troubleshooting.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is part of FlameOS and follows the same licensing terms.

## Support

- GitHub Issues: [flame-os/flameos-installer](https://github.com/flame-os)
- Documentation: [FlameOS Wiki](https://github.com/flame-os)
