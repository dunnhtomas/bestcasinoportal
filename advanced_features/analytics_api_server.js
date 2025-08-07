const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const Redis = require('redis');

const app = express();
const PORT = process.env.PORT || 3001;

// Redis client for analytics data
const redis = Redis.createClient({
    host: 'localhost',
    port: 6379,
    retry_strategy: (options) => {
        if (options.error && options.error.code === 'ECONNREFUSED') {
            return new Error('Redis server refused connection');
        }
        if (options.total_retry_time > 1000 * 60 * 60) {
            return new Error('Retry time exhausted');
        }
        if (options.attempt > 10) {
            return undefined;
        }
        return Math.min(options.attempt * 100, 3000);
    }
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 1000 // limit each IP to 1000 requests per windowMs
});
app.use('/api/', limiter);

// Analytics data storage
let analyticsData = {
    visitors: {
        total: 45723,
        today: 1247,
        weekly: [1200, 1900, 3000, 5000, 2300, 3200, 4100],
        countries: {
            'United States': 35,
            'United Kingdom': 18,
            'Canada': 12,
            'Germany': 10,
            'Australia': 8,
            'Others': 17
        }
    },
    casinos: {
        total: 156,
        featured: 24,
        ratings: {
            '5': 89,
            '4': 45,
            '3': 15,
            '2': 5,
            '1': 2
        },
        categories: {
            'Online Slots': 45,
            'Live Casino': 32,
            'Sports Betting': 28,
            'Poker': 21,
            'Lottery': 18,
            'Others': 12
        }
    },
    reviews: {
        total: 3429,
        pending: 23,
        approved: 3406,
        avgRating: 4.3,
        recent: [
            {
                id: 1,
                casino: 'Royal Vegas',
                user: 'CasinoFan92',
                rating: 5,
                comment: 'Excellent casino with fast withdrawals and great customer service!',
                date: new Date(Date.now() - 2 * 60 * 1000).toISOString(),
                verified: true
            },
            {
                id: 2,
                casino: 'Spin Palace',
                user: 'SlotMaster',
                rating: 4,
                comment: 'Good selection of games, bonus terms could be better.',
                date: new Date(Date.now() - 15 * 60 * 1000).toISOString(),
                verified: true
            },
            {
                id: 3,
                casino: 'Lucky Spins',
                user: 'BonusHunter',
                rating: 5,
                comment: 'No deposit bonus worked perfectly, great for trying new games!',
                date: new Date(Date.now() - 60 * 60 * 1000).toISOString(),
                verified: false
            }
        ]
    },
    search: {
        totalQueries: 12847,
        topQueries: [
            { query: 'no deposit bonus', count: 1247 },
            { query: 'live casino', count: 987 },
            { query: 'free spins', count: 834 },
            { query: 'high roller', count: 723 },
            { query: 'mobile casino', count: 645 }
        ],
        filters: {
            'bonus_type': 67,
            'game_type': 54,
            'country': 43,
            'rating': 38,
            'deposit_method': 29
        }
    },
    performance: {
        avgResponseTime: 89,
        uptime: 99.97,
        errors: {
            '4xx': 23,
            '5xx': 2
        },
        apiCalls: {
            total: 89234,
            successful: 89209,
            failed: 25
        }
    }
};

// System status data
let systemStatus = {
    services: [
        { name: 'Web Server', status: 'healthy', uptime: '99.98%', lastCheck: new Date() },
        { name: 'API Server', status: 'healthy', uptime: '99.95%', lastCheck: new Date() },
        { name: 'Database', status: 'healthy', uptime: '99.99%', lastCheck: new Date() },
        { name: 'CDN', status: 'healthy', uptime: '100%', lastCheck: new Date() },
        { name: 'SSL Certificate', status: 'healthy', uptime: '100%', lastCheck: new Date() }
    ],
    server: {
        cpu: 23,
        memory: 67,
        disk: 45,
        network: 12.5
    }
};

// Activity feed data
let activityFeed = [
    {
        id: 1,
        type: 'review',
        icon: 'fas fa-star text-yellow-400',
        message: 'New 5-star review for Royal Vegas Casino',
        time: new Date(Date.now() - 2 * 60 * 1000),
        user: 'CasinoFan92'
    },
    {
        id: 2,
        type: 'user',
        icon: 'fas fa-user text-blue-400',
        message: '127 new users registered today',
        time: new Date(Date.now() - 5 * 60 * 1000),
        count: 127
    },
    {
        id: 3,
        type: 'casino',
        icon: 'fas fa-building text-green-400',
        message: 'Diamond Elite Casino updated their bonus offer',
        time: new Date(Date.now() - 12 * 60 * 1000),
        casino: 'Diamond Elite Casino'
    }
];

// Helper functions
function formatTimeAgo(date) {
    const now = new Date();
    const diffMs = now - new Date(date);
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);
    
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins} min${diffMins > 1 ? 's' : ''} ago`;
    if (diffHours < 24) return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
    return `${diffDays} day${diffDays > 1 ? 's' : ''} ago`;
}

function updateRealTimeData() {
    // Simulate real-time updates
    analyticsData.visitors.today += Math.floor(Math.random() * 3);
    analyticsData.visitors.total += Math.floor(Math.random() * 2);
    analyticsData.performance.apiCalls.total += Math.floor(Math.random() * 50);
    analyticsData.search.totalQueries += Math.floor(Math.random() * 5);
    
    // Update server metrics
    systemStatus.server.cpu = Math.floor(Math.random() * 30) + 15;
    systemStatus.server.memory = Math.floor(Math.random() * 20) + 60;
    systemStatus.server.network = (Math.random() * 10 + 5).toFixed(1);
    
    // Update last check times
    systemStatus.services.forEach(service => {
        service.lastCheck = new Date();
    });
}

// API Routes

// Dashboard Overview
app.get('/api/dashboard/overview', (req, res) => {
    const overview = {
        metrics: {
            totalCasinos: analyticsData.casinos.total,
            activeUsers: analyticsData.visitors.today,
            totalReviews: analyticsData.reviews.total,
            apiRequests: analyticsData.performance.apiCalls.total
        },
        trends: {
            casinos: '+3 this week',
            users: `+${Math.floor(Math.random() * 100 + 50)} today`,
            reviews: `+${Math.floor(Math.random() * 20 + 10)} today`,
            api: '+12.5% vs yesterday'
        }
    };
    res.json(overview);
});

// Analytics Data
app.get('/api/analytics', (req, res) => {
    res.json(analyticsData);
});

app.get('/api/analytics/visitors', (req, res) => {
    res.json(analyticsData.visitors);
});

app.get('/api/analytics/casinos', (req, res) => {
    res.json(analyticsData.casinos);
});

app.get('/api/analytics/reviews', (req, res) => {
    res.json(analyticsData.reviews);
});

app.get('/api/analytics/search', (req, res) => {
    res.json(analyticsData.search);
});

// System Status
app.get('/api/system/status', (req, res) => {
    res.json(systemStatus);
});

app.get('/api/system/health', (req, res) => {
    const healthy = systemStatus.services.every(service => service.status === 'healthy');
    res.json({
        status: healthy ? 'healthy' : 'degraded',
        services: systemStatus.services.length,
        healthy: systemStatus.services.filter(s => s.status === 'healthy').length,
        timestamp: new Date()
    });
});

// Activity Feed
app.get('/api/activity', (req, res) => {
    const formattedFeed = activityFeed.map(activity => ({
        ...activity,
        timeAgo: formatTimeAgo(activity.time)
    }));
    res.json(formattedFeed);
});

// Real-time updates endpoint
app.get('/api/realtime/updates', (req, res) => {
    updateRealTimeData();
    res.json({
        visitors: analyticsData.visitors,
        performance: systemStatus.server,
        timestamp: new Date()
    });
});

// Casino management endpoints
app.get('/api/casinos', (req, res) => {
    const casinos = [
        {
            id: 1,
            name: 'Royal Vegas Casino',
            rating: 4.8,
            reviews: 1247,
            bonus: 'Up to $1200 + 120 Free Spins',
            licensed: true,
            featured: true,
            category: 'Online Slots'
        },
        {
            id: 2,
            name: 'Spin Palace',
            rating: 4.6,
            reviews: 987,
            bonus: '100% Match Bonus up to $400',
            licensed: true,
            featured: true,
            category: 'Live Casino'
        },
        {
            id: 3,
            name: 'Lucky Spins',
            rating: 4.5,
            reviews: 654,
            bonus: 'No Deposit: 50 Free Spins',
            licensed: true,
            featured: false,
            category: 'Online Slots'
        }
    ];
    
    res.json(casinos);
});

// Reviews management
app.post('/api/reviews', (req, res) => {
    const { casinoId, rating, comment, userId } = req.body;
    
    if (!casinoId || !rating || !comment || !userId) {
        return res.status(400).json({ error: 'Missing required fields' });
    }
    
    const newReview = {
        id: analyticsData.reviews.total + 1,
        casinoId,
        rating,
        comment,
        userId,
        date: new Date().toISOString(),
        verified: false,
        helpful: 0
    };
    
    analyticsData.reviews.recent.unshift(newReview);
    analyticsData.reviews.total++;
    analyticsData.reviews.pending++;
    
    // Add to activity feed
    activityFeed.unshift({
        id: activityFeed.length + 1,
        type: 'review',
        icon: 'fas fa-star text-yellow-400',
        message: `New ${rating}-star review submitted`,
        time: new Date(),
        user: userId
    });
    
    res.status(201).json(newReview);
});

// Search tracking
app.post('/api/search/track', (req, res) => {
    const { query, filters, results } = req.body;
    
    analyticsData.search.totalQueries++;
    
    // Update top queries
    const existingQuery = analyticsData.search.topQueries.find(q => q.query === query);
    if (existingQuery) {
        existingQuery.count++;
    } else if (analyticsData.search.topQueries.length < 10) {
        analyticsData.search.topQueries.push({ query, count: 1 });
    }
    
    // Track filter usage
    if (filters) {
        Object.keys(filters).forEach(filter => {
            if (analyticsData.search.filters[filter]) {
                analyticsData.search.filters[filter]++;
            } else {
                analyticsData.search.filters[filter] = 1;
            }
        });
    }
    
    res.json({ tracked: true, timestamp: new Date() });
});

// Error handling
app.use((err, req, res, next) => {
    console.error('Error:', err.stack);
    res.status(500).json({ 
        error: 'Internal server error',
        message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Endpoint not found' });
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 Analytics API Server running on port ${PORT}`);
    console.log(`📊 Dashboard data endpoints available at http://localhost:${PORT}/api/`);
    console.log(`🔍 Available endpoints:`);
    console.log(`   GET  /api/dashboard/overview - Dashboard metrics`);
    console.log(`   GET  /api/analytics - Full analytics data`);
    console.log(`   GET  /api/system/status - System status`);
    console.log(`   GET  /api/activity - Activity feed`);
    console.log(`   GET  /api/casinos - Casino listings`);
    console.log(`   POST /api/reviews - Submit review`);
    console.log(`   POST /api/search/track - Track search queries`);
    
    // Start real-time updates
    setInterval(updateRealTimeData, 30000); // Update every 30 seconds
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('📴 Analytics API server shutting down gracefully...');
    process.exit(0);
});

module.exports = app;
