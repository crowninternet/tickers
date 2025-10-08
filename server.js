const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const fs = require('fs-extra');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3002;
const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-this-in-production';

// Security middleware with relaxed CSP for development
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net", "https://fonts.googleapis.com", "https://cdnjs.cloudflare.com"],
            scriptSrc: ["'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net"],
            scriptSrcAttr: ["'unsafe-inline'"],
            fontSrc: ["'self'", "https://fonts.gstatic.com", "https://cdnjs.cloudflare.com"],
            imgSrc: ["'self'", "data:", "https:"],
            connectSrc: ["'self'", "https://www.alphavantage.co", "https://api.coingecko.com", "https://query1.finance.yahoo.com", "https://cdn.jsdelivr.net", "https://api.allorigins.win"],
            frameSrc: ["'none'"],
            objectSrc: ["'none'"],
            upgradeInsecureRequests: []
        }
    }
}));
app.use(cors({
    origin: process.env.NODE_ENV === 'production' ? false : true,
    credentials: true
}));

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.'
});
app.use(limiter);

// Auth rate limiting (stricter)
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // limit each IP to 5 auth requests per windowMs
    message: 'Too many authentication attempts, please try again later.'
});

app.use(express.json({ limit: '10mb' }));
app.use(express.static('.'));

// Data directories
const DATA_DIR = path.join(__dirname, 'data');
const USERS_FILE = path.join(DATA_DIR, 'users.json');
const USER_TICKERS_DIR = path.join(DATA_DIR, 'user_tickers');

// Ensure data directories exist
fs.ensureDirSync(DATA_DIR);
fs.ensureDirSync(USER_TICKERS_DIR);

// Initialize users file if it doesn't exist
if (!fs.existsSync(USERS_FILE)) {
    fs.writeJsonSync(USERS_FILE, { users: [] });
}

// Middleware to verify JWT token
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ error: 'Access token required' });
    }

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.status(403).json({ error: 'Invalid or expired token' });
        }
        req.user = user;
        next();
    });
};

// Validation middleware
const validateRegistration = [
    body('username').isLength({ min: 3, max: 20 }).withMessage('Username must be 3-20 characters'),
    body('email').isEmail().withMessage('Valid email required'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
    (req, res, next) => {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }
        next();
    }
];

const validateLogin = [
    body('username').notEmpty().withMessage('Username required'),
    body('password').notEmpty().withMessage('Password required'),
    (req, res, next) => {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }
        next();
    }
];

// Routes

// Register new user
app.post('/api/register', authLimiter, validateRegistration, async (req, res) => {
    try {
        const { username, email, password } = req.body;
        
        // Read existing users
        const usersData = fs.readJsonSync(USERS_FILE);
        
        // Check if user already exists
        if (usersData.users.find(u => u.username === username || u.email === email)) {
            return res.status(400).json({ error: 'Username or email already exists' });
        }
        
        // Hash password
        const saltRounds = 12;
        const hashedPassword = await bcrypt.hash(password, saltRounds);
        
        // Create new user
        const newUser = {
            id: Date.now().toString(),
            username,
            email,
            password: hashedPassword,
            createdAt: new Date().toISOString(),
            lastLogin: null
        };
        
        // Save user
        usersData.users.push(newUser);
        fs.writeJsonSync(USERS_FILE, usersData, { spaces: 2 });
        
        // Create user's ticker file
        const userTickersFile = path.join(USER_TICKERS_DIR, `${newUser.id}.json`);
        fs.writeJsonSync(userTickersFile, {
            userId: newUser.id,
            username: newUser.username,
            tickers: ['SPX', 'DJI', 'IXIC', 'BTC', 'GOLD', 'SILVER'], // Default tickers
            createdAt: new Date().toISOString(),
            lastUpdated: new Date().toISOString()
        }, { spaces: 2 });
        
        // Generate JWT token
        const token = jwt.sign(
            { userId: newUser.id, username: newUser.username },
            JWT_SECRET,
            { expiresIn: '24h' }
        );
        
        res.status(201).json({
            message: 'User registered successfully',
            token,
            user: {
                id: newUser.id,
                username: newUser.username,
                email: newUser.email
            }
        });
        
    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Login user
app.post('/api/login', authLimiter, validateLogin, async (req, res) => {
    try {
        const { username, password } = req.body;
        
        // Read users
        const usersData = fs.readJsonSync(USERS_FILE);
        const user = usersData.users.find(u => u.username === username);
        
        if (!user) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        // Verify password
        const isValidPassword = await bcrypt.compare(password, user.password);
        if (!isValidPassword) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        // Update last login
        user.lastLogin = new Date().toISOString();
        fs.writeJsonSync(USERS_FILE, usersData, { spaces: 2 });
        
        // Generate JWT token
        const token = jwt.sign(
            { userId: user.id, username: user.username },
            JWT_SECRET,
            { expiresIn: '24h' }
        );
        
        res.json({
            message: 'Login successful',
            token,
            user: {
                id: user.id,
                username: user.username,
                email: user.email
            }
        });
        
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Get user's tickers
app.get('/api/tickers', authenticateToken, (req, res) => {
    try {
        const userTickersFile = path.join(USER_TICKERS_DIR, `${req.user.userId}.json`);
        
        if (!fs.existsSync(userTickersFile)) {
            return res.status(404).json({ error: 'User tickers not found' });
        }
        
        const tickerData = fs.readJsonSync(userTickersFile);
        res.json(tickerData);
        
    } catch (error) {
        console.error('Get tickers error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Update user's tickers
app.put('/api/tickers', authenticateToken, (req, res) => {
    try {
        const { tickers } = req.body;
        
        if (!Array.isArray(tickers)) {
            return res.status(400).json({ error: 'Tickers must be an array' });
        }
        
        const userTickersFile = path.join(USER_TICKERS_DIR, `${req.user.userId}.json`);
        
        // Read existing data
        let tickerData;
        if (fs.existsSync(userTickersFile)) {
            tickerData = fs.readJsonSync(userTickersFile);
        } else {
            tickerData = {
                userId: req.user.userId,
                username: req.user.username,
                tickers: [],
                createdAt: new Date().toISOString()
            };
        }
        
        // Update tickers
        tickerData.tickers = tickers;
        tickerData.lastUpdated = new Date().toISOString();
        
        // Save updated data
        fs.writeJsonSync(userTickersFile, tickerData, { spaces: 2 });
        
        res.json({
            message: 'Tickers updated successfully',
            tickers: tickerData.tickers
        });
        
    } catch (error) {
        console.error('Update tickers error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Verify token endpoint
app.get('/api/verify', authenticateToken, (req, res) => {
    res.json({
        valid: true,
        user: {
            id: req.user.userId,
            username: req.user.username
        }
    });
});

// Logout endpoint (client-side token removal)
app.post('/api/logout', authenticateToken, (req, res) => {
    res.json({ message: 'Logout successful' });
});

// Serve the main dashboard
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Something went wrong!' });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Route not found' });
});

app.listen(PORT, () => {
    console.log(`Financial Dashboard server running on port ${PORT}`);
    console.log(`Data directory: ${DATA_DIR}`);
    console.log(`Users file: ${USERS_FILE}`);
    console.log(`User tickers directory: ${USER_TICKERS_DIR}`);
});
