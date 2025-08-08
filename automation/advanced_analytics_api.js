const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { Pool } = require('pg');
const Redis = require('redis');

const app = express();
const PORT = process.env.PORT || 3002;

// Security middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 1000 // limit each IP to 1000 requests per windowMs
});
app.use('/api/', limiter);

// Database connections
const pgPool = new Pool({
    host: 'localhost',
    port: 5432,
    database: 'bestcasinoportal',
    user: 'casino_admin',
    password: 'casino_secure_password_2025',
});

const redis = Redis.createClient({
    host: 'localhost',
    port: 6379
});

// Advanced analytics data storage
let advancedAnalytics = {
    userBehavior: {
        pageViews: {},
        sessionDuration: [],
        bounceRate: 0.23,
        conversionRate: 0.087,
        userFlow: [
            { page: 'homepage', visits: 15420, nextPages: ['casinos', 'bonuses', 'reviews'] },
            { page: 'casinos', visits: 8930, nextPages: ['casino-detail', 'compare', 'bonuses'] },
            { page: 'bonuses', visits: 6720, nextPages: ['casino-detail', 'terms', 'claim'] },
            { page: 'reviews', visits: 4890, nextPages: ['casino-detail', 'write-review', 'casinos'] }
        ],
        heatmapData: {
            homepage: {
                clicks: [
                    { x: 250, y: 150, intensity: 85 },
                    { x: 400, y: 300, intensity: 72 },
                    { x: 600, y: 450, intensity: 91 }
                ]
            }
        }
    },
    
    performance: {
        loadTimes: {
            avg: 1.2,
            p95: 2.8,
            p99: 4.1
        },
        coreWebVitals: {
            LCP: 1.8, // Largest Contentful Paint
            FID: 45,  // First Input Delay (ms)
            CLS: 0.05 // Cumulative Layout Shift
        },
        apiPerformance: {
            endpoints: [
                { path: '/api/casinos', avgResponseTime: 124, errorRate: 0.002 },
                { path: '/api/bonuses', avgResponseTime: 89, errorRate: 0.001 },
                { path: '/api/reviews', avgResponseTime: 156, errorRate: 0.003 }
            ]
        }
    },
    
    business: {
        revenue: {
            daily: [2890, 3150, 2980, 3420, 3890, 4120, 3780],
            monthly: 89450,
            yearly: 1125600
        },
        affiliateClicks: {
            total: 45230,
            conversion: 0.087,
            topCasinos: [
                { name: 'Royal Vegas', clicks: 8940, conversions: 287 },
                { name: 'Spin Palace', clicks: 6720, conversions: 198 },
                { name: 'Lucky Spins', clicks: 5890, conversions: 167 }
            ]
        },
        userSegments: {
            newUsers: 0.34,
            returningUsers: 0.66,
            highValueUsers: 0.12,
            segments: [
                { name: 'Bonus Hunters', percentage: 0.28, avgValue: 145 },
                { name: 'High Rollers', percentage: 0.08, avgValue: 890 },
                { name: 'Casual Players', percentage: 0.64, avgValue: 67 }
            ]
        }
    },
    
    geo: {
        countries: {
            'United States': { visitors: 12450, revenue: 34560 },
            'United Kingdom': { visitors: 8930, revenue: 28900 },
            'Canada': { visitors: 6780, revenue: 19800 },
            'Germany': { visitors: 4560, revenue: 15600 },
            'Australia': { visitors: 3890, revenue: 12300 }
        },
        cities: [
            { name: 'New York', visitors: 2890, lat: 40.7128, lng: -74.0060 },
            { name: 'London', visitors: 2340, lat: 51.5074, lng: -0.1278 },
            { name: 'Toronto', visitors: 1890, lat: 43.6532, lng: -79.3832 }
        ]
    },
    
    realTime: {
        currentVisitors: 247,
        activePages: {
            '/': 89,
            '/casinos': 67,
            '/bonuses': 43,
            '/reviews': 32,
            '/casino/royal-vegas': 16
        },
        liveEvents: []
    }
};

// Machine Learning Insights (Simulated)
let mlInsights = {
    predictions: {
        nextHourTraffic: 1847,
        conversionProbability: 0.094,
        churnRisk: 0.23,
        optimalPublishTime: '14:30',
        trendingKeywords: ['no deposit bonus', 'live casino', 'crypto casino']
    },
    
    recommendations: [
        {
            type: 'content',
            title: 'Create Mobile Casino Guide',
            impact: 'high',
            expectedUplift: 0.15,
            reasoning: 'Mobile traffic is 67% but mobile-specific content is lacking'
        },
        {
            type: 'ux',
            title: 'Optimize Bonus Comparison Tool',
            impact: 'medium',
            expectedUplift: 0.08,
            reasoning: 'Users spend 3.2 minutes on bonus pages but 45% bounce rate'
        },
        {
            type: 'performance',
            title: 'Implement Lazy Loading for Casino Images',
            impact: 'medium',
            expectedUplift: 0.06,
            reasoning: 'Page load time can be reduced by 0.4s for casino listing pages'
        }
    ],
    
    anomalies: [
        {
            metric: 'bounce_rate',
            current: 0.34,
            expected: 0.23,
            severity: 'medium',
            timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000)
        }
    ]
};

// Advanced API Routes

// Real-time analytics dashboard
app.get('/api/analytics/realtime', (req, res) => {
    // Simulate real-time updates
    advancedAnalytics.realTime.currentVisitors += Math.floor(Math.random() * 10 - 5);
    advancedAnalytics.realTime.currentVisitors = Math.max(200, Math.min(300, advancedAnalytics.realTime.currentVisitors));
    
    res.json({
        success: true,
        data: advancedAnalytics.realTime,
        timestamp: new Date()
    });
});

// User behavior analytics
app.get('/api/analytics/user-behavior', (req, res) => {
    res.json({
        success: true,
        data: advancedAnalytics.userBehavior
    });
});

// Performance analytics
app.get('/api/analytics/performance', (req, res) => {
    res.json({
        success: true,
        data: advancedAnalytics.performance
    });
});

// Business analytics
app.get('/api/analytics/business', (req, res) => {
    res.json({
        success: true,
        data: advancedAnalytics.business
    });
});

// Geographic analytics
app.get('/api/analytics/geo', (req, res) => {
    res.json({
        success: true,
        data: advancedAnalytics.geo
    });
});

// Machine Learning insights
app.get('/api/analytics/ml-insights', (req, res) => {
    res.json({
        success: true,
        data: mlInsights
    });
});

// Custom analytics query
app.post('/api/analytics/query', (req, res) => {
    const { metric, timeRange, filters, groupBy } = req.body;
    
    // Simulate custom query processing
    const mockData = {
        metric: metric,
        timeRange: timeRange,
        data: [
            { date: '2025-08-01', value: Math.floor(Math.random() * 1000) + 500 },
            { date: '2025-08-02', value: Math.floor(Math.random() * 1000) + 500 },
            { date: '2025-08-03', value: Math.floor(Math.random() * 1000) + 500 },
            { date: '2025-08-04', value: Math.floor(Math.random() * 1000) + 500 },
            { date: '2025-08-05', value: Math.floor(Math.random() * 1000) + 500 }
        ]
    };
    
    res.json({
        success: true,
        query: { metric, timeRange, filters, groupBy },
        data: mockData
    });
});

// A/B Test Analytics
app.get('/api/analytics/ab-tests', (req, res) => {
    const abTests = [
        {
            id: 'homepage-cta-v2',
            name: 'Homepage CTA Button Color',
            status: 'running',
            variants: [
                { name: 'Control (Blue)', traffic: 50, conversions: 127, conversionRate: 0.084 },
                { name: 'Variant (Green)', traffic: 50, conversions: 145, conversionRate: 0.096 }
            ],
            significance: 0.87,
            startDate: '2025-08-01',
            estimatedEndDate: '2025-08-15'
        },
        {
            id: 'casino-card-layout',
            name: 'Casino Card Layout Test',
            status: 'completed',
            variants: [
                { name: 'Grid Layout', traffic: 50, conversions: 89, conversionRate: 0.089 },
                { name: 'List Layout', traffic: 50, conversions: 67, conversionRate: 0.067 }
            ],
            significance: 0.95,
            winner: 'Grid Layout',
            startDate: '2025-07-15',
            endDate: '2025-07-30'
        }
    ];
    
    res.json({
        success: true,
        data: abTests
    });
});

// Cohort Analysis
app.get('/api/analytics/cohorts', (req, res) => {
    const cohortData = {
        registrationCohorts: [
            {
                period: '2025-07',
                users: 1240,
                retention: {
                    day1: 0.72,
                    day7: 0.45,
                    day30: 0.23,
                    day90: 0.12
                }
            },
            {
                period: '2025-06',
                users: 1156,
                retention: {
                    day1: 0.69,
                    day7: 0.42,
                    day30: 0.21,
                    day90: 0.11
                }
            }
        ],
        behaviorCohorts: {
            bonusHunters: {
                size: 890,
                avgLifetimeValue: 234,
                churnRate: 0.18
            },
            highRollers: {
                size: 156,
                avgLifetimeValue: 1240,
                churnRate: 0.08
            }
        }
    };
    
    res.json({
        success: true,
        data: cohortData
    });
});

// Event tracking
app.post('/api/analytics/track', (req, res) => {
    const { event, properties, userId, sessionId } = req.body;
    
    // Store event (in production, this would go to a proper analytics database)
    const eventData = {
        event,
        properties,
        userId,
        sessionId,
        timestamp: new Date(),
        ip: req.ip,
        userAgent: req.get('User-Agent')
    };
    
    // Add to real-time events
    advancedAnalytics.realTime.liveEvents.unshift(eventData);
    if (advancedAnalytics.realTime.liveEvents.length > 50) {
        advancedAnalytics.realTime.liveEvents.pop();
    }
    
    res.json({
        success: true,
        message: 'Event tracked successfully'
    });
});

// Funnel Analysis
app.get('/api/analytics/funnels', (req, res) => {
    const funnelData = {
        registrationFunnel: [
            { step: 'Landing Page', users: 10000, conversion: 1.0 },
            { step: 'Sign Up Form', users: 3400, conversion: 0.34 },
            { step: 'Email Verification', users: 2890, conversion: 0.85 },
            { step: 'First Deposit', users: 1245, conversion: 0.43 },
            { step: 'Active User', users: 987, conversion: 0.79 }
        ],
        purchaseFunnel: [
            { step: 'Casino Visit', users: 8500, conversion: 1.0 },
            { step: 'Bonus Click', users: 2340, conversion: 0.275 },
            { step: 'Registration', users: 890, conversion: 0.38 },
            { step: 'Deposit', users: 456, conversion: 0.51 },
            { step: 'Play', users: 378, conversion: 0.83 }
        ]
    };
    
    res.json({
        success: true,
        data: funnelData
    });
});

// Custom dashboard configuration
app.post('/api/analytics/dashboard/save', (req, res) => {
    const { dashboardName, widgets, layout } = req.body;
    
    // In production, save to database
    const dashboardConfig = {
        id: Date.now().toString(),
        name: dashboardName,
        widgets,
        layout,
        createdAt: new Date(),
        userId: req.headers['user-id'] || 'anonymous'
    };
    
    res.json({
        success: true,
        data: dashboardConfig,
        message: 'Dashboard saved successfully'
    });
});

// Get dashboard configurations
app.get('/api/analytics/dashboards', (req, res) => {
    const dashboards = [
        {
            id: '1',
            name: 'Executive Summary',
            description: 'High-level KPIs and business metrics',
            isDefault: true,
            widgets: ['revenue', 'users', 'conversion', 'traffic']
        },
        {
            id: '2',
            name: 'Marketing Performance',
            description: 'Marketing campaigns and acquisition metrics',
            isDefault: false,
            widgets: ['acquisition', 'campaigns', 'channels', 'cost']
        },
        {
            id: '3',
            name: 'User Experience',
            description: 'User behavior and experience metrics',
            isDefault: false,
            widgets: ['behavior', 'performance', 'satisfaction', 'bugs']
        }
    ];
    
    res.json({
        success: true,
        data: dashboards
    });
});

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        service: 'Advanced Analytics API',
        version: '2.0.0',
        timestamp: new Date(),
        uptime: process.uptime(),
        features: [
            'Real-time analytics',
            'User behavior tracking',
            'Performance monitoring',
            'Business intelligence',
            'Machine learning insights',
            'A/B testing',
            'Cohort analysis',
            'Funnel analysis',
            'Custom dashboards'
        ]
    });
});

// Helper function to simulate real-time data updates
function updateRealTimeData() {
    // Update current visitors
    advancedAnalytics.realTime.currentVisitors += Math.floor(Math.random() * 6 - 3);
    advancedAnalytics.realTime.currentVisitors = Math.max(180, Math.min(320, advancedAnalytics.realTime.currentVisitors));
    
    // Update page activity
    const pages = Object.keys(advancedAnalytics.realTime.activePages);
    pages.forEach(page => {
        advancedAnalytics.realTime.activePages[page] += Math.floor(Math.random() * 4 - 2);
        advancedAnalytics.realTime.activePages[page] = Math.max(0, advancedAnalytics.realTime.activePages[page]);
    });
    
    // Add random events
    if (Math.random() < 0.3) {
        const events = ['casino_click', 'bonus_claim', 'review_submit', 'newsletter_signup'];
        const randomEvent = events[Math.floor(Math.random() * events.length)];
        
        advancedAnalytics.realTime.liveEvents.unshift({
            event: randomEvent,
            timestamp: new Date(),
            userId: `user_${Math.floor(Math.random() * 1000)}`,
            properties: { page: pages[Math.floor(Math.random() * pages.length)] }
        });
        
        if (advancedAnalytics.realTime.liveEvents.length > 50) {
            advancedAnalytics.realTime.liveEvents.pop();
        }
    }
}

// Start real-time updates
setInterval(updateRealTimeData, 5000); // Update every 5 seconds

// Error handling
app.use((err, req, res, next) => {
    console.error('Error:', err.stack);
    res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        success: false,
        error: 'Endpoint not found'
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 Advanced Analytics API Server running on port ${PORT}`);
    console.log(`📊 Advanced analytics endpoints available at http://localhost:${PORT}/api/analytics/`);
    console.log(`🔍 Available endpoints:`);
    console.log(`   GET  /api/analytics/realtime - Real-time dashboard data`);
    console.log(`   GET  /api/analytics/user-behavior - User behavior analytics`);
    console.log(`   GET  /api/analytics/performance - Performance metrics`);
    console.log(`   GET  /api/analytics/business - Business intelligence`);
    console.log(`   GET  /api/analytics/geo - Geographic analytics`);
    console.log(`   GET  /api/analytics/ml-insights - ML predictions & recommendations`);
    console.log(`   POST /api/analytics/query - Custom analytics queries`);
    console.log(`   GET  /api/analytics/ab-tests - A/B test results`);
    console.log(`   GET  /api/analytics/cohorts - Cohort analysis`);
    console.log(`   GET  /api/analytics/funnels - Funnel analysis`);
    console.log(`   POST /api/analytics/track - Event tracking`);
    console.log(`   GET  /api/analytics/dashboards - Dashboard configurations`);
    
    console.log(`🧠 AI-powered insights and real-time analytics ready!`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('📴 Advanced Analytics API server shutting down gracefully...');
    process.exit(0);
});

module.exports = app;
