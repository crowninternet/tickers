# Financial Dashboard with User Authentication

A secure financial dashboard that allows users to track their personalized stock portfolios with real-time market data.

## Features

- **User Authentication**: Secure registration and login system
- **Personalized Portfolios**: Each user can manage their own ticker list
- **Real-time Data**: Live market data from multiple sources
- **Secure Storage**: Encrypted passwords and secure JSON file storage
- **Responsive Design**: Works on desktop and mobile devices

## Security Features

- Password encryption using bcryptjs (12 salt rounds)
- JWT token-based authentication
- Rate limiting on authentication endpoints
- Helmet.js for security headers
- Input validation and sanitization
- Secure file-based data storage

## Installation

1. **Install Node.js dependencies**:
   ```bash
   npm install
   ```

2. **Set environment variables** (optional):
   ```bash
   export JWT_SECRET="your-super-secret-jwt-key"
   export PORT=3002
   export NODE_ENV=production
   ```

3. **Start the server**:
   ```bash
   # Development mode with auto-restart
   npm run dev
   
   # Production mode
   npm start
   ```

4. **Access the dashboard**:
   Open your browser and navigate to `http://localhost:3002`

## Data Storage

The application uses secure JSON file storage:

- **User Data**: `data/users.json` - Contains encrypted user credentials
- **User Tickers**: `data/user_tickers/[userId].json` - Individual user ticker lists
- **Automatic Creation**: Data directories and files are created automatically

## API Endpoints

### Authentication
- `POST /api/register` - Register new user
- `POST /api/login` - User login
- `POST /api/logout` - User logout
- `GET /api/verify` - Verify JWT token

### User Data
- `GET /api/tickers` - Get user's ticker list
- `PUT /api/tickers` - Update user's ticker list

## User Flow

1. **Registration**: New users create an account with username, email, and password
2. **Login**: Users authenticate with their credentials
3. **Dashboard**: Personalized dashboard with user's selected tickers
4. **Ticker Management**: Add/remove tickers from their portfolio
5. **Data Persistence**: All changes are saved securely to the server

## Default Tickers

New users start with these default tickers:
- SPX (S&P 500)
- DJI (Dow Jones)
- IXIC (Nasdaq)
- BTC (Bitcoin)
- GOLD (Gold)
- SILVER (Silver)

## Security Considerations

- Passwords are hashed with bcryptjs (12 salt rounds)
- JWT tokens expire after 24 hours
- Rate limiting prevents brute force attacks
- Input validation prevents injection attacks
- CORS is configured for security
- Helmet.js provides security headers

## Development

To run in development mode with auto-restart:
```bash
npm run dev
```

The server will automatically restart when you make changes to the code.

## Production Deployment

For production deployment:

1. Set a strong JWT_SECRET environment variable
2. Set NODE_ENV=production
3. Use a reverse proxy (nginx) for SSL termination
4. Consider using a process manager like PM2
5. Set up proper logging and monitoring

## File Structure

```
tickers/
├── server.js              # Main server file
├── package.json           # Dependencies and scripts
├── index.html            # Frontend dashboard
├── data/                 # Data storage directory
│   ├── users.json       # User credentials (encrypted)
│   └── user_tickers/    # Individual user ticker files
└── README.md            # This file
```

## Troubleshooting

**Server won't start**: Check if port 3002 is available
**Authentication fails**: Verify JWT_SECRET is set
**Data not saving**: Check file permissions on data directory
**CORS errors**: Verify CORS configuration in server.js

## License

MIT License - see LICENSE file for details.
