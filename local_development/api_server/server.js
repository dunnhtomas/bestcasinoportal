const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const cors = require('cors');
const morgan = require('morgan');
const compression = require('compression');

const app = express();
const PORT = process.env.PORT || 4000;

// Security middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
            fontSrc: ["'self'", "https://fonts.gstatic.com"],
            imgSrc: ["'self'", "data:", "https:"],
            scriptSrc: ["'self'"]
        }
    },
    hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true
    }
}));

// CORS configuration
app.use(cors({
    origin: process.env.NODE_ENV === 'production' 
        ? ['https://bestcasinoportal.com', 'https://www.bestcasinoportal.com'] 
        : ['http://localhost:3000'],
    credentials: true
}));

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: {
        error: 'Too many requests from this IP, please try again later.',
        retryAfter: 900
    },
    standardHeaders: true,
    legacyHeaders: false
});

app.use('/api/', limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Compression middleware
app.use(compression());

// Logging middleware
app.use(morgan('combined'));

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        uptime: process.uptime(),
        services: {
            api: 'running',
            database: 'connected', // TODO: Add actual DB health check
            cache: 'connected'      // TODO: Add actual cache health check
        }
    });
});

// API Routes

// Casino listings endpoint
app.get('/api/casinos', async (req, res) => {
    try {
        // TODO: Replace with actual database query
        const casinos = [
            {
                id: 1,
                name: "Royal Vegas Casino",
                rating: 4.8,
                bonus: "100% up to $1,200",
                features: ["Live Dealers", "Mobile App", "Crypto Payments"],
                url: "https://bestcasinoportal.com/go/royal-vegas"
            },
            {
                id: 2,
                name: "Spin Palace Casino",
                rating: 4.7,
                bonus: "100% up to $1,000",
                features: ["600+ Games", "24/7 Support", "Fast Withdrawals"],
                url: "https://bestcasinoportal.com/go/spin-palace"
            }
        ];
        
        res.json({
            success: true,
            data: casinos,
            total: casinos.length
        });
    } catch (error) {
        console.error('Error fetching casinos:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch casino data'
        });
    }
});

// Search endpoint
app.get('/api/search', async (req, res) => {
    try {
        const { q, category, rating, bonus } = req.query;
        
        if (!q) {
            return res.status(400).json({
                success: false,
                error: 'Search query is required'
            });
        }
        
        // TODO: Implement actual search logic with Elasticsearch
        const searchResults = [
            {
                id: 1,
                title: "Best Canadian Online Casinos 2025",
                type: "article",
                excerpt: "Discover the top-rated online casinos for Canadian players...",
                url: "/articles/best-canadian-casinos-2025"
            }
        ];
        
        res.json({
            success: true,
            data: searchResults,
            query: q,
            filters: { category, rating, bonus },
            total: searchResults.length
        });
    } catch (error) {
        console.error('Search error:', error);
        res.status(500).json({
            success: false,
            error: 'Search failed'
        });
    }
});

// Newsletter subscription endpoint
app.post('/api/newsletter', async (req, res) => {
    try {
        const { email } = req.body;
        
        if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
            return res.status(400).json({
                success: false,
                error: 'Valid email address is required'
            });
        }
        
        // TODO: Implement actual newsletter subscription logic
        console.log('Newsletter subscription:', email);
        
        res.json({
            success: true,
            message: 'Successfully subscribed to newsletter'
        });
    } catch (error) {
        console.error('Newsletter subscription error:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to subscribe to newsletter'
        });
    }
});

// Bonus tracking endpoint
app.post('/api/track-bonus', async (req, res) => {
    try {
        const { casinoId, bonusType, userId } = req.body;
        
        if (!casinoId || !bonusType) {
            return res.status(400).json({
                success: false,
                error: 'Casino ID and bonus type are required'
            });
        }
        
        // TODO: Implement actual bonus tracking logic
        console.log('Bonus tracking:', { casinoId, bonusType, userId });
        
        res.json({
            success: true,
            message: 'Bonus click tracked successfully'
        });
    } catch (error) {
        console.error('Bonus tracking error:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to track bonus click'
        });
    }
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        success: false,
        error: process.env.NODE_ENV === 'production' 
            ? 'Internal server error' 
            : err.message
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        success: false,
        error: 'Endpoint not found'
    });
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    process.exit(0);
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 BestCasinoPortal API Server running on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
    console.log(`🎰 Environment: ${process.env.NODE_ENV || 'development'}`);
});

module.exports = app;
