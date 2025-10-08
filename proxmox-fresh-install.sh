#!/bin/bash

# Proxmox VE Fresh Installation Script
# Based on successful community scripts and best practices
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/crowninternet/tickers/main/proxmox-fresh-install.sh)"

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
    print_success "Running as root"
}

# Function to check if running on Debian
check_debian() {
    if [[ ! -f /etc/debian_version ]]; then
        print_error "This script is designed for Debian systems"
        exit 1
    fi
    
    local debian_version=$(cat /etc/debian_version)
    print_success "Running on Debian $debian_version"
}

# Function to update system
update_system() {
    print_status "Updating system packages..."
    
    apt update
    apt full-upgrade -y
    
    print_success "System updated successfully"
}

# Function to install essential packages
install_essential_packages() {
    print_status "Installing essential packages..."
    
    apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates
    
    print_success "Essential packages installed"
}

# Function to add Proxmox repository
add_proxmox_repository() {
    print_status "Adding Proxmox VE repository..."
    
    # Add Proxmox VE repository
    echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
    
    # Add Proxmox VE repository key
    wget -qO- http://download.proxmox.com/debian/proxmox-release-bookworm.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
    
    # Update package lists
    apt update
    
    print_success "Proxmox VE repository added"
}

# Function to install Proxmox VE
install_proxmox_ve() {
    print_status "Installing Proxmox VE packages..."
    
    # Install Proxmox VE packages
    apt install -y proxmox-ve postfix open-iscsi
    
    print_success "Proxmox VE packages installed"
}

# Function to configure postfix
configure_postfix() {
    print_status "Configuring postfix..."
    
    # Configure postfix for local delivery only
    debconf-set-selections <<< "postfix postfix/mailname string $(hostname -f)"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Local only'"
    
    print_success "Postfix configured"
}

# Function to remove Debian default kernel
remove_debian_kernel() {
    print_status "Removing Debian default kernel..."
    
    # Remove Debian default kernel
    apt remove -y linux-image-amd64 'linux-image-6.*' || true
    
    print_success "Debian default kernel removed"
}

# Function to update GRUB
update_grub() {
    print_status "Updating GRUB bootloader..."
    
    update-grub
    
    print_success "GRUB updated"
}

# Function to configure network
configure_network() {
    print_status "Configuring network..."
    
    # Get the primary network interface
    local primary_interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [[ -n "$primary_interface" ]]; then
        print_status "Primary network interface: $primary_interface"
        
        # Create network configuration
        cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto $primary_interface
iface $primary_interface inet manual

auto vmbr0
iface vmbr0 inet dhcp
    bridge-ports $primary_interface
    bridge-stp off
    bridge-fd 0
EOF
        
        print_success "Network configured with bridge vmbr0"
    else
        print_warning "Could not detect primary network interface"
    fi
}

# Function to disable enterprise repository
disable_enterprise_repo() {
    print_status "Disabling enterprise repository..."
    
    # Disable enterprise repository if it exists
    if [[ -f /etc/apt/sources.list.d/pve-enterprise.list ]]; then
        sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
        print_success "Enterprise repository disabled"
    fi
}

# Function to enable no-subscription repository
enable_no_subscription_repo() {
    print_status "Enabling no-subscription repository..."
    
    # Enable no-subscription repository
    echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
    
    # Update package lists
    apt update
    
    print_success "No-subscription repository enabled"
}

# Function to show final information
show_final_info() {
    echo
    print_success "Proxmox VE installation completed successfully!"
    echo
    print_status "Installation Summary:"
    print_status "- Proxmox VE installed and configured"
    print_status "- Network bridge vmbr0 configured"
    print_status "- Enterprise repository disabled"
    print_status "- No-subscription repository enabled"
    echo
    print_status "Next Steps:"
    print_status "1. The system will reboot in 10 seconds"
    print_status "2. After reboot, access the web interface at: https://$(hostname -I | awk '{print $1}'):8006"
    print_status "3. Default login: root / (your current root password)"
    echo
    print_warning "Important:"
    print_warning "- Change the default password after first login"
    print_warning "- Configure SSL certificates for production use"
    print_warning "- Set up proper firewall rules"
    echo
    print_status "The system will reboot in 10 seconds..."
    sleep 10
}

# Function to handle errors
handle_error() {
    print_error "An error occurred during installation"
    print_status "Check the logs above for details"
    exit 1
}

# Set error trap
trap handle_error ERR

# Main installation process
main() {
    print_status "Starting Proxmox VE Fresh Installation"
    print_status "This script will install Proxmox VE on Debian 12"
    echo
    
    # Check prerequisites
    check_root
    check_debian
    
    # Installation steps
    update_system
    install_essential_packages
    add_proxmox_repository
    configure_postfix
    install_proxmox_ve
    remove_debian_kernel
    update_grub
    configure_network
    disable_enterprise_repo
    enable_no_subscription_repo
    
    # Show final information
    show_final_info
    
    # Reboot the system
    print_status "Rebooting system..."
    reboot
}

# Run main function
main "$@"
