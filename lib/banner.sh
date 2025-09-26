#!/bin/bash

# ASCII Art Banner
show_banner() {
    clear
    echo -e "${RED}"
    cat << "EOF"
    ███████ ██       █████  ███    ███ ███████  ██████  ███████ 
    ██      ██      ██   ██ ████  ████ ██      ██    ██ ██      
    █████   ██      ███████ ██ ████ ██ █████   ██    ██ ███████ 
    ██      ██      ██   ██ ██  ██  ██ ██      ██    ██      ██ 
    ██      ███████ ██   ██ ██      ██ ███████  ██████  ███████ 
EOF
    echo -e "${NC}"
    echo -e "${CYAN}            FlameOS Installer${NC}"
    echo ""
}
