#!/bin/bash

# Proxmox Container Template Installer for Financial Dashboard
# Debian 12 Container Template: debian-12-standard_12.12-1_amd64.tar.zst
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/crowninternet/tickers/main/proxmox-financial-dashboard-v6.sh)"

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
STORAGE=""
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

# Function to detect available storage
detect_storage() {
    print_status "Detecting available storage for containers..."
    
    # Get all available storage
    print_status "Available storage options:"
    pvesm status --type dir,thin,lvm,zfs | while read line; do
        if [[ "$line" =~ ^(local|local-lvm|local-zfs|local-thin) ]]; then
            echo "  $line"
        fi
    done
    
    # Get available storage that supports containers
    local available_storage=$(pvesm status --type dir,thin,lvm,zfs | grep -E '^(local|local-lvm|local-zfs|local-thin)' | awk '{print $1}' | head -1)
    
    if [[ -n "$available_storage" ]]; then
        STORAGE="$available_storage"
        print_success "Auto-detected storage: ${STORAGE}"
    else
        print_warning "Could not auto-detect storage. You'll need to specify manually."
        STORAGE=""
    fi
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
    while true; do
        read -p "Enter IP Address with CIDR (e.g., 192.168.1.100/24): " IP_ADDRESS
        if [[ -z "$IP_ADDRESS" ]]; then
            break  # Allow empty for DHCP
        elif [[ "$IP_ADDRESS" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
            break  # Valid CIDR format
        else
            print_error "Invalid IP format. Please use CIDR notation (e.g., 192.168.1.100/24)"
        fi
    done
    
    if [[ -n "$IP_ADDRESS" ]]; then
        read -p "Enter Gateway (e.g., 192.168.1.1): " GATEWAY
    fi
    
    # Storage Configuration
    echo
    print_status "Storage Configuration:"
    if [[ -n "$STORAGE" ]]; then
        print_status "Auto-detected storage: ${STORAGE}"
        read -p "Use detected storage? (Y/n): " use_detected
        if [[ "$use_detected" =~ ^[Nn]$ ]]; then
            STORAGE=""
        fi
    fi
    
    if [[ -z "$STORAGE" ]]; then
        print_status "Available storage options:"
        pvesm status --type dir,thin,lvm,zfs | grep -E '^(local|local-lvm|local-zfs|local-thin)' | awk '{print "  " $1 " - " $2 " (" $3 ")"}'
        echo
        print_status "Storage recommendations:"
        print_status "- 'local' (directory): Most compatible, works on all systems"
        print_status "- 'local-lvm' (LVM): Better performance, requires LVM setup"
        print_status "- 'local-zfs' (ZFS): Advanced features, requires ZFS setup"
        echo
        while [[ -z "$STORAGE" ]]; do
            read -p "Enter Storage name (recommended: local): " STORAGE
            if [[ -z "$STORAGE" ]]; then
                print_error "Storage name is required"
            else
                # Validate storage exists
                if ! pvesm status | grep -q "^${STORAGE} "; then
                    print_error "Storage '${STORAGE}' does not exist"
                    STORAGE=""
                fi
            fi
        done
    fi
    
    print_success "Selected storage: ${STORAGE}"
    
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
    print_status "Storage: ${STORAGE}"
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

# Function to fix LVM thin pool issues
fix_lvm_thin_pool() {
    if [[ "$STORAGE" == "local-lvm" ]]; then
        print_status "Checking LVM thin pool status..."
        
        # Clear any LVM locks first
        print_status "Clearing LVM locks..."
        vgchange -ay pve 2>/dev/null || true
        lvchange -ay pve/data 2>/dev/null || true
        
        # Check if thin pool is in read-only mode
        local lv_status=$(lvdisplay pve/data 2>/dev/null | grep "LV Write Access" | awk '{print $4}')
        if [[ "$lv_status" == "read/write" ]]; then
            print_success "LVM thin pool is writable"
            return 0
        fi
        
        print_warning "LVM thin pool is in read-only mode, attempting to fix..."
        
        # Try to reactivate the thin pool
        if lvchange -ay pve/data 2>/dev/null; then
            print_status "LVM thin pool reactivated"
        else
            print_warning "Could not reactivate LVM thin pool automatically"
        fi
        
        # Try to repair the thin pool if needed
        print_status "Attempting to repair LVM thin pool..."
        lvconvert --repair pve/data 2>/dev/null || true
        
        # Check status again
        sleep 3
        local lv_status_after=$(lvdisplay pve/data 2>/dev/null | grep "LV Write Access" | awk '{print $4}')
        if [[ "$lv_status_after" == "read/write" ]]; then
            print_success "LVM thin pool is now writable"
            return 0
        else
            print_warning "LVM thin pool is still in read-only mode"
            print_status "This may cause container creation to fail"
            return 1
        fi
    fi
    
    return 0
}

# Function to check storage space
check_storage_space() {
    print_status "Checking storage space..."
    
    # Get storage info
    local storage_info=$(pvesm status | grep "^${STORAGE} ")
    if [[ -z "$storage_info" ]]; then
        print_error "Storage ${STORAGE} not found"
        return 1
    fi
    
    # Extract available space (column 4)
    local available_space=$(echo "$storage_info" | awk '{print $4}')
    print_status "Available space on ${STORAGE}: ${available_space}"
    
    # Check if it's a reasonable amount (basic check)
    if [[ "$available_space" == "0" ]] || [[ "$available_space" == "-" ]]; then
        print_warning "Storage ${STORAGE} appears to have no available space"
        print_status "You may need to:"
        print_status "1. Free up space on the storage"
        print_status "2. Use a different storage"
        print_status "3. Reduce the disk size"
        return 1
    fi
    
    return 0
}

# Function to create container
create_container() {
    print_status "Creating container ${CONTAINER_ID}..."
    
    # Fix LVM thin pool issues if using local-lvm
    if ! fix_lvm_thin_pool; then
        print_warning "LVM thin pool issues detected, but continuing..."
    fi
    
    # Check storage space first
    if ! check_storage_space; then
        print_error "Storage space check failed"
        exit 1
    fi
    
    # Build pct create command
    local create_cmd="pct create ${CONTAINER_ID} /var/lib/vz/template/cache/${TEMPLATE_NAME}"
    create_cmd="${create_cmd} --hostname ${CONTAINER_NAME}"
    create_cmd="${create_cmd} --password ${ROOT_PASSWORD}"
    create_cmd="${create_cmd} --memory ${MEMORY}"
    create_cmd="${create_cmd} --cores ${CPU_CORES}"
    
    # Handle different storage types
    if [[ "$STORAGE" == "local-lvm" ]]; then
        # For LVM thin, use the format that works
        create_cmd="${create_cmd} --rootfs ${STORAGE}:${DISK_SIZE}"
    else
        # For other storage types
        create_cmd="${create_cmd} --rootfs ${STORAGE}:${DISK_SIZE}"
    fi
    
    create_cmd="${create_cmd} --net0 name=eth0,bridge=${BRIDGE}"
    
    # Add IP configuration if provided
    if [[ -n "$IP_ADDRESS" ]]; then
        create_cmd="${create_cmd},ip=${IP_ADDRESS}"
        if [[ -n "$GATEWAY" ]]; then
            create_cmd="${create_cmd},gw=${GATEWAY}"
        fi
    else
        create_cmd="${create_cmd},ip=dhcp"
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
        print_error "Failed to create container with first attempt"
        
        # Try alternative approach for LVM thin pool
        if [[ "$STORAGE" == "local-lvm" ]]; then
            print_status "Trying alternative LVM approach..."
            
            # Try with different container ID
            local alt_id=$((CONTAINER_ID + 100))
            local alt_cmd="pct create ${alt_id} /var/lib/vz/template/cache/${TEMPLATE_NAME}"
            alt_cmd="${alt_cmd} --hostname ${CONTAINER_NAME}-alt"
            alt_cmd="${alt_cmd} --password ${ROOT_PASSWORD}"
            alt_cmd="${alt_cmd} --memory ${MEMORY}"
            alt_cmd="${alt_cmd} --cores ${CPU_CORES}"
            alt_cmd="${alt_cmd} --rootfs ${STORAGE}:${DISK_SIZE}"
            alt_cmd="${alt_cmd} --net0 name=eth0,bridge=${BRIDGE}"
            
            # Add IP configuration if provided
            if [[ -n "$IP_ADDRESS" ]]; then
                alt_cmd="${alt_cmd},ip=${IP_ADDRESS}"
                if [[ -n "$GATEWAY" ]]; then
                    alt_cmd="${alt_cmd},gw=${GATEWAY}"
                fi
            else
                alt_cmd="${alt_cmd},ip=dhcp"
            fi
            
            # Add DNS servers
            alt_cmd="${alt_cmd} --nameserver ${DNS_SERVERS}"
            
            # Add features
            alt_cmd="${alt_cmd} --features nesting=1"
            
            # Add startup options
            alt_cmd="${alt_cmd} --onboot 1"
            
            print_status "Trying alternative command: ${alt_cmd}"
            
            if eval "$alt_cmd"; then
                print_success "Container ${alt_id} created successfully with alternative approach"
                CONTAINER_ID=${alt_id}
            else
                print_error "Alternative approach also failed"
                print_status "Common issues and solutions:"
                print_status "1. Storage space: Check if ${STORAGE} has enough space"
                print_status "2. LVM issues: Try using 'local' storage instead of 'local-lvm'"
                print_status "3. Container ID: ID ${CONTAINER_ID} might already be in use"
                print_status "4. Network: Check if IP ${IP_ADDRESS} is available"
                print_status ""
                print_status "To check storage: pvesm status"
                print_status "To check container IDs: pct list"
                exit 1
            fi
        else
            print_error "Failed to create container"
            print_status "Common issues and solutions:"
            print_status "1. Storage space: Check if ${STORAGE} has enough space"
            print_status "2. LVM issues: Try using 'local' storage instead of 'local-lvm'"
            print_status "3. Container ID: ID ${CONTAINER_ID} might already be in use"
            print_status "4. Network: Check if IP ${IP_ADDRESS} is available"
            print_status ""
            print_status "To check storage: pvesm status"
            print_status "To check container IDs: pct list"
            exit 1
        fi
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
    detect_storage
    
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
