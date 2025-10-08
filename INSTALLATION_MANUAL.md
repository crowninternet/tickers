# Financial Dashboard - cPanel Installation Manual

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Server Requirements](#server-requirements)
3. [File Upload](#file-upload)
4. [Node.js Backend Setup](#nodejs-backend-setup)
5. [Database Setup](#database-setup)
6. [Configuration](#configuration)
7. [Security Setup](#security-setup)
8. [Testing](#testing)
9. [Troubleshooting](#troubleshooting)
10. [Maintenance](#maintenance)

## Prerequisites

Before installing, ensure you have:
- cPanel hosting account with Node.js support
- FTP/SFTP access or File Manager access
- Basic knowledge of file management
- Domain name pointed to your hosting account

## Server Requirements

### Minimum Requirements:
- **PHP**: 7.4 or higher
- **Node.js**: 14.x or higher (check with hosting provider)
- **Storage**: 100MB free space
- **Memory**: 512MB RAM minimum
- **Bandwidth**: Sufficient for API calls to financial data providers

### Recommended:
- **Node.js**: 16.x or 18.x
- **Storage**: 500MB free space
- **Memory**: 1GB RAM
- **SSL Certificate**: For secure data transmission

## File Upload

### Method 1: Using cPanel File Manager

1. **Log into cPanel**
   - Access your hosting control panel
   - Navigate to "File Manager"

2. **Navigate to public_html**
   - Click on `public_html` folder
   - This is your website's root directory

3. **Upload Files**
   - Create a new folder called `financial-dashboard`
   - Upload the following files to this folder:
     ```
     financial-dashboard/
     ├── index.html
     ├── server.js
     ├── package.json
     ├── README.md
     └── data/
         ├── users.json
         └── user_tickers/
     ```

### Method 2: Using FTP/SFTP

1. **Connect via FTP Client**
   - Use FileZilla, WinSCP, or similar
   - Host: your-domain.com
   - Username: your cPanel username
   - Password: your cPanel password
   - Port: 21 (FTP) or 22 (SFTP)

2. **Upload Files**
   - Navigate to `/public_html/financial-dashboard/`
   - Upload all application files maintaining folder structure

## Node.js Backend Setup

### Step 1: Enable Node.js in cPanel

1. **Access Node.js App**
   - In cPanel, find "Node.js Selector" or "Node.js Apps"
   - Click "Create Application"

2. **Configure Application**
   - **Application Root**: `/public_html/financial-dashboard`
   - **Application URL**: `/financial-dashboard`
   - **Node.js Version**: Select 16.x or 18.x (latest available)
   - **Application Mode**: Production

3. **Create Application**
   - Click "Create"
   - Note the generated port number

### Step 2: Install Dependencies

1. **Access Terminal/SSH**
   - In cPanel, find "Terminal" or request SSH access
   - Navigate to your application directory:
     ```bash
     cd public_html/financial-dashboard
     ```

2. **Install NPM Packages**
   ```bash
     npm install express bcryptjs jsonwebtoken express-validator helmet cors express-rate-limit fs-extra
     ```

### Step 3: Configure Application

1. **Update server.js Port**
   - Open `server.js` in File Manager
   - Find the port configuration line:
     ```javascript
     const PORT = process.env.PORT || 3002;
     ```
   - Replace `3002` with the port number from Step 1

2. **Set Environment Variables**
   - In cPanel Node.js App settings
   - Add environment variables:
     ```
     NODE_ENV=production
     PORT=your-assigned-port
     ```

## Database Setup

### Option 1: File-based Storage (Default)
The app uses JSON files for data storage. Ensure proper permissions:

1. **Set File Permissions**
   ```bash
   chmod 755 data/
   chmod 644 data/users.json
   chmod 755 data/user_tickers/
   ```

2. **Create Initial Files**
   - `data/users.json`: `{}`
   - `data/user_tickers/`: Empty directory

### Option 2: MySQL Database (Advanced)
If you prefer MySQL over file storage:

1. **Create Database**
   - In cPanel, go to "MySQL Databases"
   - Create new database: `financial_dashboard`
   - Create user and assign permissions

2. **Update server.js**
   - Add MySQL connection code
   - Replace file-based storage with database queries

## Configuration

### Step 1: API Keys Setup

1. **Alpha Vantage API Keys**
   - Visit: https://www.alphavantage.co/support/#api-key
   - Register for free API key(s)
   - Update `index.html` with your keys:
     ```javascript
     const ALPHA_VANTAGE_API_KEYS = [
         'YOUR_API_KEY_1',
         'YOUR_API_KEY_2',
         // Add up to 6 keys for rotation
     ];
     ```

2. **CoinGecko API**
   - Free tier available at https://www.coingecko.com/en/api
   - No key required for basic usage
   - Update rate limits if needed

### Step 2: Domain Configuration

1. **Update CORS Settings**
   - In `server.js`, update the CORS origin:
     ```javascript
     app.use(cors({
         origin: ['https://yourdomain.com', 'https://www.yourdomain.com']
     }));
     ```

2. **Update Content Security Policy**
   - Modify CSP headers in `server.js` to include your domain

### Step 3: SSL Configuration

1. **Enable SSL Certificate**
   - In cPanel, go to "SSL/TLS"
   - Enable "Force HTTPS Redirect"

2. **Update Mixed Content**
   - Ensure all API calls use HTTPS
   - Update any HTTP references in the code

## Security Setup

### Step 1: File Permissions

```bash
# Set appropriate permissions
find public_html/financial-dashboard -type d -exec chmod 755 {} \;
find public_html/financial-dashboard -type f -exec chmod 644 {} \;
chmod 600 public_html/financial-dashboard/data/users.json
```

### Step 2: Hide Sensitive Files

1. **Create .htaccess**
   - In the `financial-dashboard` folder, create `.htaccess`:
     ```apache
     # Deny access to sensitive files
     <Files "package.json">
         Order Allow,Deny
         Deny from all
     </Files>
     
     <Files "server.js">
         Order Allow,Deny
         Deny from all
     </Files>
     
     # Protect data directory
     <Directory "data">
         Order Allow,Deny
         Deny from all
     </Directory>
     ```

### Step 3: Rate Limiting

The app includes built-in rate limiting. Monitor usage and adjust if needed:

```javascript
// In server.js, adjust rate limits
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100 // limit each IP to 100 requests per windowMs
});
```

## Testing

### Step 1: Start the Application

1. **In cPanel Node.js App**
   - Click "Start App"
   - Monitor logs for any errors

2. **Check Application Status**
   - Verify the app is running
   - Note the assigned port number

### Step 2: Test Functionality

1. **Access the Application**
   - Visit: `https://yourdomain.com/financial-dashboard`
   - Verify the page loads correctly

2. **Test Features**
   - Create a user account
   - Add/remove tickers
   - View charts
   - Test all time periods (1D, 7D, 30D, etc.)

3. **Monitor Console**
   - Open browser developer tools
   - Check for JavaScript errors
   - Verify API calls are working

### Step 3: Performance Testing

1. **Load Testing**
   - Test with multiple users
   - Monitor server resources
   - Check API rate limits

2. **Mobile Testing**
   - Test on various devices
   - Verify responsive design
   - Check touch interactions

## Troubleshooting

### Common Issues

#### 1. Application Won't Start
**Symptoms**: Node.js app fails to start
**Solutions**:
- Check Node.js version compatibility
- Verify all dependencies are installed
- Check port conflicts
- Review error logs in cPanel

#### 2. API Calls Failing
**Symptoms**: Charts not loading, "Too many requests" errors
**Solutions**:
- Verify API keys are correct
- Check API rate limits
- Ensure CORS is properly configured
- Monitor API usage

#### 3. File Permission Errors
**Symptoms**: Cannot create users, save tickers
**Solutions**:
- Fix file permissions:
  ```bash
  chmod 755 data/
  chmod 644 data/users.json
  ```
- Ensure web server can write to data directory

#### 4. SSL/HTTPS Issues
**Symptoms**: Mixed content warnings, API calls blocked
**Solutions**:
- Enable SSL certificate
- Force HTTPS redirect
- Update all HTTP references to HTTPS

#### 5. Memory/Performance Issues
**Symptoms**: Slow loading, timeouts
**Solutions**:
- Upgrade hosting plan
- Optimize API calls
- Implement caching
- Monitor server resources

### Debug Mode

Enable debug logging by adding to `server.js`:
```javascript
if (process.env.NODE_ENV !== 'production') {
    console.log('Debug mode enabled');
}
```

### Log Files

Monitor these log files in cPanel:
- **Error Logs**: `public_html/financial-dashboard/error.log`
- **Access Logs**: Available in cPanel Logs section
- **Node.js Logs**: In Node.js App interface

## Maintenance

### Regular Tasks

#### Weekly:
- Monitor API usage and limits
- Check for new user registrations
- Review error logs
- Test core functionality

#### Monthly:
- Update API keys if needed
- Review and rotate API keys
- Check disk space usage
- Update dependencies if security patches available

#### Quarterly:
- Review server performance
- Update Node.js version if available
- Backup user data
- Security audit

### Backup Procedures

1. **Automated Backup**
   - Set up cPanel automated backups
   - Include the entire `financial-dashboard` folder

2. **Manual Backup**
   ```bash
   # Create backup
   tar -czf financial-dashboard-backup-$(date +%Y%m%d).tar.gz public_html/financial-dashboard/
   ```

3. **Data Backup**
   - Regularly backup `data/` folder
   - Export user data to secure location

### Updates

1. **Application Updates**
   - Download new version
   - Backup current installation
   - Upload new files
   - Test thoroughly before going live

2. **Dependency Updates**
   ```bash
   npm update
   npm audit fix
   ```

### Monitoring

Set up monitoring for:
- Application uptime
- API rate limit usage
- Server resource usage
- Error rates
- User registration patterns

## Support

### Getting Help

1. **Check Logs**: Always check error logs first
2. **Documentation**: Review this manual and README.md
3. **Hosting Support**: Contact your hosting provider for server issues
4. **Community**: Check GitHub issues or forums

### Contact Information

- **Hosting Issues**: Contact your cPanel hosting provider
- **Application Issues**: Review the code documentation
- **API Issues**: Check Alpha Vantage and CoinGecko documentation

---

## Quick Reference

### Essential Files
- `index.html` - Main application
- `server.js` - Backend server
- `package.json` - Dependencies
- `data/users.json` - User data
- `data/user_tickers/` - User ticker preferences

### Important URLs
- Application: `https://yourdomain.com/financial-dashboard`
- cPanel: `https://yourdomain.com/cpanel`
- Node.js App: In cPanel → Node.js Apps

### Key Commands
```bash
# Navigate to app directory
cd public_html/financial-dashboard

# Install dependencies
npm install

# Start application (if manual)
node server.js

# Check permissions
ls -la data/
```

This manual should provide everything needed to successfully install and maintain the Financial Dashboard on a cPanel server. Follow each step carefully and test thoroughly before going live.


