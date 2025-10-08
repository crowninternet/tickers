# Financial Dashboard - Proxmox Container Installation

This repository contains a fully self-contained Proxmox container installation script for deploying the Financial Dashboard on Debian 12.

## Quick Installation

Run this single command on your Proxmox VE node:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/crowninternet/tickers/main/proxmox-financial-dashboard-v7.sh)"
```

## Prerequisites

- Proxmox VE node with root access
- Debian 12 container template: `debian-12-standard_12.12-1_amd64.tar.zst`
- Template must be downloaded to `/var/lib/vz/template/cache/`

## What the Script Does

1. **Container Creation**: Creates a new LXC container using Debian 12 template
2. **Network Configuration**: Sets up IP address and network settings
3. **Node.js Installation**: Installs Node.js 18.x and npm
4. **Application Deployment**: Downloads and installs the Financial Dashboard
5. **Service Configuration**: Creates systemd service for automatic startup
6. **Firewall Setup**: Configures UFW firewall with appropriate rules
7. **Security**: Sets up proper user permissions and security measures

## Configuration Options

The script will prompt you for:

- **Container ID**: Unique identifier (default: 100)
- **Container Name**: Human-readable name (default: financial-dashboard)
- **Root Password**: Password for container root user
- **IP Address**: Static IP with CIDR notation (e.g., 192.168.1.100/24) - **REQUIRED format**
- **Gateway**: Network gateway IP
- **Memory**: RAM allocation (default: 512MB)
- **Disk Size**: Storage allocation (default: 2GB)
- **CPU Cores**: Number of CPU cores (default: 1)

## Default Settings

- **Template**: debian-12-standard_12.12-1_amd64.tar.zst
- **Storage**: local
- **Bridge**: vmbr0
- **DNS**: 8.8.8.8, 8.8.4.4
- **Port**: 3002
- **Auto-start**: Enabled

## Post-Installation

After installation, you can access:

- **Web Interface**: `http://YOUR_IP:3002`
- **SSH Access**: `ssh root@YOUR_IP`

## Management Commands

### Container Management
```bash
# Start container
pct start 100

# Stop container
pct stop 100

# Restart container
pct restart 100

# Destroy container (if needed)
pct destroy 100
```

### Service Management
```bash
# Start Financial Dashboard service
pct exec 100 -- systemctl start financial-dashboard

# Stop service
pct exec 100 -- systemctl stop financial-dashboard

# Restart service
pct exec 100 -- systemctl restart financial-dashboard

# View service status
pct exec 100 -- systemctl status financial-dashboard

# View logs
pct exec 100 -- journalctl -u financial-dashboard -f
```

## Security Notes

- The script uses a default JWT secret for development
- **Important**: Change the JWT_SECRET in production
- Firewall is configured to only allow SSH (22) and HTTP (3002)
- Container runs with minimal privileges

## Troubleshooting

### Template Not Found
If you get "Template not found" error:
1. Go to Proxmox Web UI
2. Navigate to your local storage
3. Go to CT Templates tab
4. Download `debian-12-standard_12.12-1_amd64.tar.zst`

### Container Won't Start
- Check if the container ID is already in use
- Verify network configuration
- Check Proxmox logs: `journalctl -f`

### Service Issues
- Check service status: `pct exec 100 -- systemctl status financial-dashboard`
- View logs: `pct exec 100 -- journalctl -u financial-dashboard -f`
- Check if port 3002 is accessible

### Network Issues
- Verify IP address is not in use
- Check gateway configuration
- Ensure bridge interface exists

## Features

- **User Authentication**: Secure login/registration system
- **Real-time Data**: Live financial data from multiple sources
- **Portfolio Management**: Track multiple tickers and symbols
- **Responsive Design**: Works on desktop and mobile
- **Security**: JWT tokens, rate limiting, input validation
- **Data Persistence**: User data stored locally in container

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Proxmox VE documentation
3. Check container logs for specific errors

## License

MIT License - see LICENSE file for details
