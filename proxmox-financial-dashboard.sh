#!/bin/bash

# Proxmox Container Template Installer for Financial Dashboard
# Debian 12 Container Template: debian-12-standard_12.12-1_amd64.tar.zst
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/crowninternet/tickers/main/proxmox-financial-dashboard.sh)"

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_ID="100"
CONTAINER_NAME="financial-dashboard"
TEMPLATE_NAME="debian-12-standard_12.12-1_amd64.tar.zst"
STORAGE="local"
MEMORY="512"
DISK_SIZE="2G"
CPU_CORES="1"
PASSWORD=""
ROOT_PASSWORD=""
BRIDGE="vmbr0"
IP_ADDRESS=""
GATEWAY=""
DNS_SERVERS="8.8.8.8,8.8.4.4"

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

# Function to check if running on Proxmox
check_proxmox() {
    if [[ ! -f /etc/pve/local/pve-ssl.pem ]]; then
        print_error "This script must be run on a Proxmox VE node"
        exit 1
    fi
    print_success "Proxmox VE environment detected"
}

# Function to check if template exists
check_template() {
    if [[ ! -f "/var/lib/vz/template/cache/${TEMPLATE_NAME}" ]]; then
        print_error "Template ${TEMPLATE_NAME} not found in /var/lib/vz/template/cache/"
        print_status "Please download the template first:"
        print_status "1. Go to Proxmox Web UI"
        print_status "2. Navigate to local storage"
        print_status "3. Go to CT Templates tab"
        print_status "4. Download debian-12-standard_12.12-1_amd64.tar.zst"
        exit 1
    fi
    print_success "Template ${TEMPLATE_NAME} found"
}

# Function to get user input
get_user_input() {
    print_status "Financial Dashboard Container Setup"
    echo
    
    # Container ID
    read -p "Enter Container ID (default: ${CONTAINER_ID}): " input_id
    CONTAINER_ID=${input_id:-$CONTAINER_ID}
    
    # Container Name
    read -p "Enter Container Name (default: ${CONTAINER_NAME}): " input_name
    CONTAINER_NAME=${input_name:-$CONTAINER_NAME}
    
    # Root Password
    while [[ -z "$ROOT_PASSWORD" ]]; do
        read -s -p "Enter root password for container: " ROOT_PASSWORD
        echo
        if [[ -z "$ROOT_PASSWORD" ]]; then
            print_error "Root password cannot be empty"
        fi
    done
    
    # Network Configuration
    read -p "Enter IP Address (e.g., 192.168.1.100/24): " IP_ADDRESS
    if [[ -n "$IP_ADDRESS" ]]; then
        read -p "Enter Gateway (e.g., 192.168.1.1): " GATEWAY
    fi
    
    # Resource Configuration
    read -p "Enter Memory (default: ${MEMORY}): " input_memory
    MEMORY=${input_memory:-$MEMORY}
    
    read -p "Enter Disk Size (default: ${DISK_SIZE}): " input_disk
    DISK_SIZE=${input_disk:-$DISK_SIZE}
    
    read -p "Enter CPU Cores (default: ${CPU_CORES}): " input_cores
    CPU_CORES=${input_cores:-$CPU_CORES}
    
    echo
    print_status "Configuration Summary:"
    print_status "Container ID: ${CONTAINER_ID}"
    print_status "Container Name: ${CONTAINER_NAME}"
    print_status "Template: ${TEMPLATE_NAME}"
    print_status "Memory: ${MEMORY}"
    print_status "Disk: ${DISK_SIZE}"
    print_status "CPU Cores: ${CPU_CORES}"
    print_status "IP Address: ${IP_ADDRESS:-DHCP}"
    print_status "Gateway: ${GATEWAY:-Default}"
    echo
    
    read -p "Continue with installation? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Installation cancelled"
        exit 0
    fi
}

# Function to create container
create_container() {
    print_status "Creating container ${CONTAINER_ID}..."
    
    # Build pct create command
    local create_cmd="pct create ${CONTAINER_ID} /var/lib/vz/template/cache/${TEMPLATE_NAME}"
    create_cmd="${create_cmd} --hostname ${CONTAINER_NAME}"
    create_cmd="${create_cmd} --password ${ROOT_PASSWORD}"
    create_cmd="${create_cmd} --memory ${MEMORY}"
    create_cmd="${create_cmd} --cores ${CPU_CORES}"
    create_cmd="${create_cmd} --rootfs ${STORAGE}:${DISK_SIZE}"
    create_cmd="${create_cmd} --net0 name=eth0,bridge=${BRIDGE}"
    
    # Add IP configuration if provided
    if [[ -n "$IP_ADDRESS" ]]; then
        create_cmd="${create_cmd},ip=${IP_ADDRESS}"
        if [[ -n "$GATEWAY" ]]; then
            create_cmd="${create_cmd},gw=${GATEWAY}"
        fi
    else
        create_cmd="${create_cmd},dhcp=1"
    fi
    
    # Add DNS servers
    create_cmd="${create_cmd} --nameserver ${DNS_SERVERS}"
    
    # Add features
    create_cmd="${create_cmd} --features nesting=1"
    
    # Add startup options
    create_cmd="${create_cmd} --onboot 1"
    
    print_status "Executing: ${create_cmd}"
    
    if eval "$create_cmd"; then
        print_success "Container ${CONTAINER_ID} created successfully"
    else
        print_error "Failed to create container"
        exit 1
    fi
}

# Function to start container
start_container() {
    print_status "Starting container ${CONTAINER_ID}..."
    
    if pct start ${CONTAINER_ID}; then
        print_success "Container ${CONTAINER_ID} started successfully"
    else
        print_error "Failed to start container"
        exit 1
    fi
}

# Function to wait for container to be ready
wait_for_container() {
    print_status "Waiting for container to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if pct exec ${CONTAINER_ID} -- ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            print_success "Container is ready"
            return 0
        fi
        
        print_status "Attempt ${attempt}/${max_attempts} - waiting for container..."
        sleep 2
        ((attempt++))
    done
    
    print_error "Container failed to become ready after ${max_attempts} attempts"
    exit 1
}

# Function to install Node.js and dependencies
install_nodejs() {
    print_status "Installing Node.js and dependencies..."
    
    # Update package list
    pct exec ${CONTAINER_ID} -- apt-get update
    
    # Install curl and other dependencies
    pct exec ${CONTAINER_ID} -- apt-get install -y curl wget gnupg2 software-properties-common
    
    # Install Node.js 18.x
    pct exec ${CONTAINER_ID} -- bash -c "curl -fsSL https://deb.nodesource.com/setup_18.x | bash -"
    pct exec ${CONTAINER_ID} -- apt-get install -y nodejs
    
    # Verify installation
    local node_version=$(pct exec ${CONTAINER_ID} -- node --version)
    local npm_version=$(pct exec ${CONTAINER_ID} -- npm --version)
    
    print_success "Node.js ${node_version} and npm ${npm_version} installed"
}

# Function to create application directory and download files
setup_application() {
    print_status "Setting up Financial Dashboard application..."
    
    # Create application directory
    pct exec ${CONTAINER_ID} -- mkdir -p /opt/financial-dashboard
    pct exec ${CONTAINER_ID} -- chown 1000:1000 /opt/financial-dashboard
    
    # Download package.json
    pct exec ${CONTAINER_ID} -- bash -c "curl -fsSL https://raw.githubusercontent.com/crowninternet/tickers/main/package.json -o /opt/financial-dashboard/package.json"
    
    # Download server.js
    pct exec ${CONTAINER_ID} -- bash -c "curl -fsSL https://raw.githubusercontent.com/crowninternet/tickers/main/server.js -o /opt/financial-dashboard/server.js"
    
    # Download index.html
    pct exec ${CONTAINER_ID} -- bash -c "curl -fsSL https://raw.githubusercontent.com/crowninternet/tickers/main/index.html -o /opt/financial-dashboard/index.html"
    
    # Create data directory
    pct exec ${CONTAINER_ID} -- mkdir -p /opt/financial-dashboard/data/user_tickers
    pct exec ${CONTAINER_ID} -- chown -R 1000:1000 /opt/financial-dashboard/data
    
    # Install npm dependencies
    pct exec ${CONTAINER_ID} -- bash -c "cd /opt/financial-dashboard && npm install"
    
    print_success "Application files downloaded and dependencies installed"
}

# Function to create systemd service
create_service() {
    print_status "Creating systemd service..."
    
    # Create service file
    pct exec ${CONTAINER_ID} -- bash -c "cat > /etc/systemd/system/financial-dashboard.service << 'EOF'
[Unit]
Description=Financial Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/financial-dashboard
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3002

[Install]
WantedBy=multi-user.target
EOF"
    
    # Reload systemd and enable service
    pct exec ${CONTAINER_ID} -- systemctl daemon-reload
    pct exec ${CONTAINER_ID} -- systemctl enable financial-dashboard
    pct exec ${CONTAINER_ID} -- systemctl start financial-dashboard
    
    print_success "Financial Dashboard service created and started"
}

# Function to configure firewall
configure_firewall() {
    print_status "Configuring firewall..."
    
    # Install ufw if not present
    pct exec ${CONTAINER_ID} -- apt-get install -y ufw
    
    # Configure firewall rules
    pct exec ${CONTAINER_ID} -- ufw --force reset
    pct exec ${CONTAINER_ID} -- ufw default deny incoming
    pct exec ${CONTAINER_ID} -- ufw default allow outgoing
    pct exec ${CONTAINER_ID} -- ufw allow ssh
    pct exec ${CONTAINER_ID} -- ufw allow 3002/tcp
    pct exec ${CONTAINER_ID} -- ufw --force enable
    
    print_success "Firewall configured"
}

# Function to display final information
show_final_info() {
    echo
    print_success "Financial Dashboard installation completed!"
    echo
    print_status "Container Information:"
    print_status "Container ID: ${CONTAINER_ID}"
    print_status "Container Name: ${CONTAINER_NAME}"
    print_status "IP Address: ${IP_ADDRESS:-$(pct exec ${CONTAINER_ID} -- hostname -I | awk '{print $1}')}"
    print_status "Port: 3002"
    echo
    print_status "Access Information:"
    print_status "Web Interface: http://${IP_ADDRESS:-$(pct exec ${CONTAINER_ID} -- hostname -I | awk '{print $1}')}:3002"
    print_status "SSH Access: ssh root@${IP_ADDRESS:-$(pct exec ${CONTAINER_ID} -- hostname -I | awk '{print $1}')}"
    echo
    print_status "Management Commands:"
    print_status "Start container: pct start ${CONTAINER_ID}"
    print_status "Stop container: pct stop ${CONTAINER_ID}"
    print_status "Restart container: pct restart ${CONTAINER_ID}"
    print_status "View logs: pct exec ${CONTAINER_ID} -- journalctl -u financial-dashboard -f"
    echo
    print_status "Service Management:"
    print_status "Start service: pct exec ${CONTAINER_ID} -- systemctl start financial-dashboard"
    print_status "Stop service: pct exec ${CONTAINER_ID} -- systemctl stop financial-dashboard"
    print_status "Restart service: pct exec ${CONTAINER_ID} -- systemctl restart financial-dashboard"
    print_status "View service status: pct exec ${CONTAINER_ID} -- systemctl status financial-dashboard"
    echo
    print_warning "Remember to change the JWT_SECRET in production!"
    print_warning "Default JWT secret is used for development only."
}

# Function to handle errors
handle_error() {
    print_error "An error occurred during installation"
    print_status "Container ${CONTAINER_ID} may need to be cleaned up"
    print_status "To remove the container: pct destroy ${CONTAINER_ID}"
    exit 1
}

# Set error trap
trap handle_error ERR

# Main installation process
main() {
    print_status "Starting Financial Dashboard Container Installation"
    print_status "Template: ${TEMPLATE_NAME}"
    echo
    
    # Check prerequisites
    check_proxmox
    check_template
    
    # Get user input
    get_user_input
    
    # Create and configure container
    create_container
    start_container
    wait_for_container
    
    # Install software
    install_nodejs
    setup_application
    create_service
    configure_firewall
    
    # Show final information
    show_final_info
}

# Run main function
main "$@"
