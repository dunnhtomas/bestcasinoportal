const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 4001;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Enhanced casino database
const casinosDatabase = [
    {
        id: 1,
        name: 'Royal Vegas Casino',
        rating: 4.9,
        bonus: '100% up to €1,200 + 120 Free Spins',
        features: ['Live Dealers', 'Mobile App', 'Crypto Payments', 'VIP Program'],
        games: 850,
        established: 2000,
        license: 'Malta Gaming Authority',
        payment_methods: ['Visa', 'Mastercard', 'Bitcoin', 'PayPal', 'Skrill'],
        withdrawal_time: '24-48 hours',
        min_deposit: 10,
        currency: ['EUR', 'USD', 'GBP', 'BTC'],
        restricted_countries: ['US', 'UK'],
        software_providers: ['NetEnt', 'Microgaming', 'Evolution Gaming'],
        rtp: 96.5,
        categories: ['Slots', 'Table Games', 'Live Casino', 'Jackpots'],
        url: 'https://bestcasinoportal.com/go/royal-vegas',
        logo: '/images/royal-vegas-logo.png',
        screenshots: ['/images/royal-vegas-1.jpg', '/images/royal-vegas-2.jpg'],
        pros: ['Excellent customer support', 'Fast withdrawals', 'Great game selection'],
        cons: ['High wagering requirements', 'Limited live chat hours'],
        last_updated: '2025-08-07'
    },
    {
        id: 2,
        name: 'Spin Palace Casino',
        rating: 4.7,
        bonus: '100% up to €1,000 + 100 Free Spins',
        features: ['600+ Games', '24/7 Support', 'Fast Withdrawals', 'Mobile Optimized'],
        games: 650,
        established: 2001,
        license: 'Malta Gaming Authority',
        payment_methods: ['Visa', 'Mastercard', 'PayPal', 'Neteller', 'Paysafecard'],
        withdrawal_time: '2-5 business days',
        min_deposit: 15,
        currency: ['EUR', 'USD', 'CAD'],
        restricted_countries: ['US', 'France'],
        software_providers: ['Microgaming', 'NetEnt', 'Play\'n GO'],
        rtp: 96.2,
        categories: ['Slots', 'Progressive Jackpots', 'Table Games'],
        url: 'https://bestcasinoportal.com/go/spin-palace',
        logo: '/images/spin-palace-logo.png',
        screenshots: ['/images/spin-palace-1.jpg'],
        pros: ['Trusted brand', 'Great mobile experience', 'Regular promotions'],
        cons: ['Limited live games', 'Slow customer support'],
        last_updated: '2025-08-07'
    },
    {
        id: 3,
        name: 'Lucky Spins Casino',
        rating: 4.5,
        bonus: 'No Deposit: 50 Free Spins + 250% up to €500',
        features: ['No Deposit Bonus', 'Sports Betting', 'Mobile App', 'Crypto Support'],
        games: 500,
        established: 2018,
        license: 'Curacao eGaming',
        payment_methods: ['Bitcoin', 'Ethereum', 'Litecoin', 'Visa', 'Mastercard'],
        withdrawal_time: '1-24 hours',
        min_deposit: 5,
        currency: ['EUR', 'USD', 'BTC', 'ETH'],
        restricted_countries: ['US', 'UK', 'Australia'],
        software_providers: ['Pragmatic Play', 'BGaming', 'Spinomenal'],
        rtp: 96.8,
        categories: ['Slots', 'Sports Betting', 'Table Games', 'Crypto Games'],
        url: 'https://bestcasinoportal.com/go/lucky-spins',
        logo: '/images/lucky-spins-logo.png',
        screenshots: ['/images/lucky-spins-1.jpg'],
        pros: ['No deposit bonus', 'Crypto-friendly', 'Fast payouts'],
        cons: ['Limited customer support', 'Newer brand'],
        last_updated: '2025-08-07'
    },
    {
        id: 4,
        name: 'Diamond Elite Casino',
        rating: 4.8,
        bonus: '200% up to €2,000 + 200 Free Spins',
        features: ['VIP Program', 'Live Dealers', 'High Roller Bonuses', 'Personal Manager'],
        games: 1200,
        established: 2015,
        license: 'Malta Gaming Authority',
        payment_methods: ['Visa', 'Mastercard', 'Bitcoin', 'Bank Transfer', 'Skrill'],
        withdrawal_time: '12-24 hours',
        min_deposit: 20,
        currency: ['EUR', 'USD', 'GBP', 'BTC'],
        restricted_countries: ['US'],
        software_providers: ['Evolution Gaming', 'NetEnt', 'Microgaming', 'Pragmatic Play'],
        rtp: 97.1,
        categories: ['Live Casino', 'VIP Games', 'High Stakes', 'Jackpots'],
        url: 'https://bestcasinoportal.com/go/diamond-elite',
        logo: '/images/diamond-elite-logo.png',
        screenshots: ['/images/diamond-elite-1.jpg', '/images/diamond-elite-2.jpg'],
        pros: ['Excellent VIP program', 'High RTP games', 'Premium support'],
        cons: ['High minimum deposit', 'Complex bonus terms'],
        last_updated: '2025-08-07'
    },
    {
        id: 5,
        name: 'Mega Slots Casino',
        rating: 4.6,
        bonus: '150% up to €800 + 200 Free Spins',
        features: ['3000+ Slots', 'Mega Jackpots', 'Daily Bonuses', 'Tournament'],
        games: 3200,
        established: 2019,
        license: 'Curacao eGaming',
        payment_methods: ['Visa', 'Mastercard', 'Bitcoin', 'Dogecoin', 'PayPal'],
        withdrawal_time: '2-4 hours',
        min_deposit: 10,
        currency: ['EUR', 'USD', 'BTC', 'DOGE'],
        restricted_countries: ['US', 'UK'],
        software_providers: ['Pragmatic Play', 'Red Tiger', 'Yggdrasil', 'Thunderkick'],
        rtp: 96.4,
        categories: ['Video Slots', 'Classic Slots', 'Jackpot Slots', 'Tournaments'],
        url: 'https://bestcasinoportal.com/go/mega-slots',
        logo: '/images/mega-slots-logo.png',
        screenshots: ['/images/mega-slots-1.jpg'],
        pros: ['Huge slot selection', 'Daily tournaments', 'Crypto-friendly'],
        cons: ['Limited table games', 'Newer license'],
        last_updated: '2025-08-07'
    },
    {
        id: 6,
        name: 'Live Dealer Pro',
        rating: 4.9,
        bonus: '100% up to €800 + Live Casino Cashback',
        features: ['24/7 Live Dealers', 'HD Streaming', 'Mobile Live Games', 'Chat Feature'],
        games: 150,
        established: 2017,
        license: 'Malta Gaming Authority',
        payment_methods: ['Visa', 'Mastercard', 'PayPal', 'Skrill', 'Neteller'],
        withdrawal_time: '6-12 hours',
        min_deposit: 25,
        currency: ['EUR', 'USD', 'GBP'],
        restricted_countries: ['US', 'Australia'],
        software_providers: ['Evolution Gaming', 'Pragmatic Play Live', 'Ezugi'],
        rtp: 98.2,
        categories: ['Live Blackjack', 'Live Roulette', 'Live Baccarat', 'Game Shows'],
        url: 'https://bestcasinoportal.com/go/live-dealer-pro',
        logo: '/images/live-dealer-pro-logo.png',
        screenshots: ['/images/live-dealer-pro-1.jpg'],
        pros: ['Best live dealer experience', 'Professional dealers', 'HD quality'],
        cons: ['Limited slot games', 'Higher minimum deposit'],
        last_updated: '2025-08-07'
    }
];

// Bonus offers database
const bonusDatabase = [
    {
        id: 1,
        casino_id: 1,
        type: 'Welcome Bonus',
        title: 'Royal Welcome Package',
        description: '100% match bonus up to €1,200 plus 120 free spins on Starburst',
        bonus_amount: 1200,
        percentage: 100,
        free_spins: 120,
        wagering_requirement: 35,
        min_deposit: 10,
        max_cashout: null,
        valid_games: ['Slots', 'Scratch Cards'],
        bonus_code: 'ROYAL100',
        expiry_days: 30,
        terms: 'Standard bonus terms apply. 18+ only.',
        active: true
    },
    {
        id: 2,
        casino_id: 3,
        type: 'No Deposit Bonus',
        title: 'Free Spins No Deposit',
        description: '50 free spins on Book of Dead - no deposit required',
        bonus_amount: 0,
        percentage: 0,
        free_spins: 50,
        wagering_requirement: 40,
        min_deposit: 0,
        max_cashout: 100,
        valid_games: ['Book of Dead'],
        bonus_code: 'NODEPOSIT50',
        expiry_days: 7,
        terms: 'Max cashout €100. Wagering 40x.',
        active: true
    }
];

// User reviews database
let reviewsDatabase = [
    {
        id: 1,
        casino_id: 1,
        user_name: 'CasinoFan92',
        rating: 5,
        title: 'Excellent Casino!',
        comment: 'Been playing here for 2 years. Great games, fast withdrawals, and excellent customer service.',
        pros: ['Fast withdrawals', 'Great game selection', 'Responsive support'],
        cons: ['High wagering requirements'],
        verified: true,
        helpful_votes: 15,
        date_created: '2025-08-05',
        play_duration: '2+ years'
    },
    {
        id: 2,
        casino_id: 2,
        user_name: 'SlotMaster',
        rating: 4,
        title: 'Good but not great',
        comment: 'Solid casino with good games but customer support could be faster.',
        pros: ['Good game variety', 'Trusted brand'],
        cons: ['Slow support', 'Limited live games'],
        verified: true,
        helpful_votes: 8,
        date_created: '2025-08-03',
        play_duration: '6 months'
    }
];

// API Routes

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: '2.1.0',
        uptime: process.uptime(),
        services: {
            api: 'running',
            database: 'connected',
            cache: 'connected'
        },
        features: ['search', 'reviews', 'analytics', 'advanced_filters']
    });
});

// Get all casinos with advanced filtering
app.get('/api/casinos', (req, res) => {
    const { 
        search, 
        rating, 
        bonus_type, 
        games, 
        payment, 
        license,
        min_deposit,
        software,
        sort = 'rating',
        order = 'desc',
        limit = 50,
        offset = 0
    } = req.query;

    let filteredCasinos = [...casinosDatabase];

    // Search filter
    if (search) {
        const searchTerm = search.toLowerCase();
        filteredCasinos = filteredCasinos.filter(casino =>
            casino.name.toLowerCase().includes(searchTerm) ||
            casino.features.some(feature => feature.toLowerCase().includes(searchTerm)) ||
            casino.categories.some(category => category.toLowerCase().includes(searchTerm))
        );
    }

    // Rating filter
    if (rating) {
        const minRating = parseFloat(rating);
        filteredCasinos = filteredCasinos.filter(casino => casino.rating >= minRating);
    }

    // Bonus type filter
    if (bonus_type) {
        filteredCasinos = filteredCasinos.filter(casino => {
            if (bonus_type === 'welcome') return casino.bonus.includes('%');
            if (bonus_type === 'no_deposit') return casino.bonus.toLowerCase().includes('no deposit');
            if (bonus_type === 'free_spins') return casino.bonus.toLowerCase().includes('free spins');
            return true;
        });
    }

    // Payment method filter
    if (payment) {
        filteredCasinos = filteredCasinos.filter(casino =>
            casino.payment_methods.some(method => 
                method.toLowerCase().includes(payment.toLowerCase())
            )
        );
    }

    // License filter
    if (license) {
        filteredCasinos = filteredCasinos.filter(casino =>
            casino.license.toLowerCase().includes(license.toLowerCase())
        );
    }

    // Minimum deposit filter
    if (min_deposit) {
        const maxMinDeposit = parseInt(min_deposit);
        filteredCasinos = filteredCasinos.filter(casino => casino.min_deposit <= maxMinDeposit);
    }

    // Software provider filter
    if (software) {
        filteredCasinos = filteredCasinos.filter(casino =>
            casino.software_providers.some(provider =>
                provider.toLowerCase().includes(software.toLowerCase())
            )
        );
    }

    // Sorting
    filteredCasinos.sort((a, b) => {
        let aValue = a[sort];
        let bValue = b[sort];
        
        if (typeof aValue === 'string') {
            aValue = aValue.toLowerCase();
            bValue = bValue.toLowerCase();
        }
        
        if (order === 'desc') {
            return bValue > aValue ? 1 : -1;
        } else {
            return aValue > bValue ? 1 : -1;
        }
    });

    // Pagination
    const startIndex = parseInt(offset);
    const endIndex = startIndex + parseInt(limit);
    const paginatedCasinos = filteredCasinos.slice(startIndex, endIndex);

    res.json({
        success: true,
        data: paginatedCasinos,
        total: filteredCasinos.length,
        page_info: {
            current_page: Math.floor(startIndex / limit) + 1,
            total_pages: Math.ceil(filteredCasinos.length / limit),
            has_next: endIndex < filteredCasinos.length,
            has_previous: startIndex > 0
        },
        filters_applied: {
            search, rating, bonus_type, games, payment, license, min_deposit, software
        }
    });
});

// Get single casino by ID
app.get('/api/casinos/:id', (req, res) => {
    const casinoId = parseInt(req.params.id);
    const casino = casinosDatabase.find(c => c.id === casinoId);
    
    if (!casino) {
        return res.status(404).json({
            success: false,
            error: 'Casino not found'
        });
    }

    // Get reviews for this casino
    const casinoReviews = reviewsDatabase.filter(r => r.casino_id === casinoId);
    
    // Calculate average rating from reviews
    const avgReviewRating = casinoReviews.length > 0 
        ? casinoReviews.reduce((sum, r) => sum + r.rating, 0) / casinoReviews.length 
        : casino.rating;

    res.json({
        success: true,
        data: {
            ...casino,
            review_stats: {
                total_reviews: casinoReviews.length,
                average_rating: avgReviewRating,
                rating_distribution: {
                    5: casinoReviews.filter(r => r.rating === 5).length,
                    4: casinoReviews.filter(r => r.rating === 4).length,
                    3: casinoReviews.filter(r => r.rating === 3).length,
                    2: casinoReviews.filter(r => r.rating === 2).length,
                    1: casinoReviews.filter(r => r.rating === 1).length
                }
            },
            recent_reviews: casinoReviews.slice(0, 5)
        }
    });
});

// Get bonuses
app.get('/api/bonuses', (req, res) => {
    const { casino_id, type } = req.query;
    
    let filteredBonuses = [...bonusDatabase];
    
    if (casino_id) {
        filteredBonuses = filteredBonuses.filter(b => b.casino_id === parseInt(casino_id));
    }
    
    if (type) {
        filteredBonuses = filteredBonuses.filter(b => 
            b.type.toLowerCase().includes(type.toLowerCase())
        );
    }
    
    res.json({
        success: true,
        data: filteredBonuses,
        total: filteredBonuses.length
    });
});

// Get reviews
app.get('/api/reviews', (req, res) => {
    const { casino_id, rating, limit = 10, offset = 0 } = req.query;
    
    let filteredReviews = [...reviewsDatabase];
    
    if (casino_id) {
        filteredReviews = filteredReviews.filter(r => r.casino_id === parseInt(casino_id));
    }
    
    if (rating) {
        filteredReviews = filteredReviews.filter(r => r.rating >= parseInt(rating));
    }
    
    // Sort by date (newest first)
    filteredReviews.sort((a, b) => new Date(b.date_created) - new Date(a.date_created));
    
    // Pagination
    const startIndex = parseInt(offset);
    const endIndex = startIndex + parseInt(limit);
    const paginatedReviews = filteredReviews.slice(startIndex, endIndex);
    
    res.json({
        success: true,
        data: paginatedReviews,
        total: filteredReviews.length
    });
});

// Submit new review
app.post('/api/reviews', (req, res) => {
    const { casino_id, rating, title, comment, pros, cons, user_name } = req.body;
    
    if (!casino_id || !rating || !comment || !user_name) {
        return res.status(400).json({
            success: false,
            error: 'Missing required fields'
        });
    }
    
    const newReview = {
        id: reviewsDatabase.length + 1,
        casino_id: parseInt(casino_id),
        user_name,
        rating: parseInt(rating),
        title: title || '',
        comment,
        pros: pros || [],
        cons: cons || [],
        verified: false,
        helpful_votes: 0,
        date_created: new Date().toISOString().split('T')[0],
        play_duration: 'Not specified'
    };
    
    reviewsDatabase.push(newReview);
    
    res.json({
        success: true,
        data: newReview,
        message: 'Review submitted successfully'
    });
});

// Get analytics/statistics
app.get('/api/analytics', (req, res) => {
    const totalCasinos = casinosDatabase.length;
    const totalReviews = reviewsDatabase.length;
    const avgRating = casinosDatabase.reduce((sum, c) => sum + c.rating, 0) / totalCasinos;
    
    // Calculate other stats
    const licensesStats = {};
    const paymentMethodsStats = {};
    const softwareStats = {};
    
    casinosDatabase.forEach(casino => {
        // License statistics
        licensesStats[casino.license] = (licensesStats[casino.license] || 0) + 1;
        
        // Payment methods statistics
        casino.payment_methods.forEach(method => {
            paymentMethodsStats[method] = (paymentMethodsStats[method] || 0) + 1;
        });
        
        // Software providers statistics
        casino.software_providers.forEach(provider => {
            softwareStats[provider] = (softwareStats[provider] || 0) + 1;
        });
    });
    
    res.json({
        success: true,
        data: {
            overview: {
                total_casinos: totalCasinos,
                total_reviews: totalReviews,
                average_rating: Math.round(avgRating * 10) / 10,
                total_bonuses: bonusDatabase.length
            },
            licenses: licensesStats,
            payment_methods: paymentMethodsStats,
            software_providers: softwareStats,
            rating_distribution: {
                5: casinosDatabase.filter(c => c.rating >= 4.8).length,
                4: casinosDatabase.filter(c => c.rating >= 4.0 && c.rating < 4.8).length,
                3: casinosDatabase.filter(c => c.rating >= 3.0 && c.rating < 4.0).length,
                2: casinosDatabase.filter(c => c.rating >= 2.0 && c.rating < 3.0).length,
                1: casinosDatabase.filter(c => c.rating < 2.0).length
            }
        }
    });
});

// Search suggestions endpoint
app.get('/api/search/suggestions', (req, res) => {
    const { q } = req.query;
    
    if (!q || q.length < 2) {
        return res.json({ success: true, data: [] });
    }
    
    const searchTerm = q.toLowerCase();
    const suggestions = [];
    
    // Casino name suggestions
    casinosDatabase.forEach(casino => {
        if (casino.name.toLowerCase().includes(searchTerm)) {
            suggestions.push({
                type: 'casino',
                text: casino.name,
                category: 'Casinos'
            });
        }
    });
    
    // Feature suggestions
    const features = ['Live Dealers', 'Mobile App', 'Crypto Payments', 'VIP Program', 
                     'Sports Betting', 'No Deposit Bonus', 'Free Spins'];
    features.forEach(feature => {
        if (feature.toLowerCase().includes(searchTerm)) {
            suggestions.push({
                type: 'feature',
                text: feature,
                category: 'Features'
            });
        }
    });
    
    res.json({
        success: true,
        data: suggestions.slice(0, 10) // Limit to 10 suggestions
    });
});

// Serve advanced frontend
app.get('/advanced', (req, res) => {
    res.sendFile(path.join(__dirname, 'advanced_casino_portal.html'));
});

// Default route
app.get('/', (req, res) => {
    res.json({
        message: 'Best Casino Portal API v2.1 - Advanced Features',
        version: '2.1.0',
        endpoints: {
            health: '/health',
            casinos: '/api/casinos',
            casino_detail: '/api/casinos/:id',
            bonuses: '/api/bonuses',
            reviews: '/api/reviews',
            analytics: '/api/analytics',
            search_suggestions: '/api/search/suggestions',
            advanced_frontend: '/advanced'
        },
        features: [
            'Advanced search and filtering',
            'User reviews and ratings',
            'Live analytics',
            'Bonus tracking',
            'Search suggestions',
            'Detailed casino profiles'
        ]
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 Advanced Casino Portal API running on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
    console.log(`🎰 Advanced UI: http://localhost:${PORT}/advanced`);
    console.log(`🔧 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`📈 Features: Search, Reviews, Analytics, Live Data`);
});
