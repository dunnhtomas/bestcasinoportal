const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const app = express();
const port = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use('/api/', limiter);

// Database connection
const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'bestcasinoportal',
  user: 'casino_admin',
  password: 'casino_secure_password_2025',
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    service: 'BestCasinoPortal API',
    version: '1.0.0'
  });
});

// Get all casinos
app.get('/api/casinos', async (req, res) => {
  try {
    const { featured, limit = 50 } = req.query;
    let query = 'SELECT * FROM casinos WHERE is_active = true';
    let params = [];
    
    if (featured === 'true') {
      query += ' AND is_featured = true';
    }
    
    query += ' ORDER BY rating DESC, created_at DESC LIMIT $1';
    params.push(limit);
    
    const result = await pool.query(query, params);
    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });
  } catch (err) {
    console.error('Error fetching casinos:', err);
    res.status(500).json({ 
      success: false,
      error: 'Failed to fetch casinos',
      message: err.message 
    });
  }
});

// Get casino by ID
app.get('/api/casinos/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'SELECT * FROM casinos WHERE id = $1 AND is_active = true',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Casino not found'
      });
    }
    
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (err) {
    console.error('Error fetching casino:', err);
    res.status(500).json({ 
      success: false,
      error: 'Failed to fetch casino',
      message: err.message 
    });
  }
});

// Get bonuses
app.get('/api/bonuses', async (req, res) => {
  try {
    const { casino_id, limit = 50 } = req.query;
    let query = `
      SELECT b.*, c.name as casino_name, c.logo_url as casino_logo
      FROM bonuses b 
      JOIN casinos c ON b.casino_id = c.id 
      WHERE b.is_active = true AND c.is_active = true
    `;
    let params = [];
    
    if (casino_id) {
      query += ' AND b.casino_id = $1';
      params.push(casino_id);
      query += ' ORDER BY b.amount DESC LIMIT $2';
      params.push(limit);
    } else {
      query += ' ORDER BY b.amount DESC LIMIT $1';
      params.push(limit);
    }
    
    const result = await pool.query(query, params);
    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });
  } catch (err) {
    console.error('Error fetching bonuses:', err);
    res.status(500).json({ 
      success: false,
      error: 'Failed to fetch bonuses',
      message: err.message 
    });
  }
});

// Search casinos
app.get('/api/search', async (req, res) => {
  try {
    const { q, category, min_rating } = req.query;
    
    if (!q) {
      return res.status(400).json({
        success: false,
        error: 'Search query is required'
      });
    }
    
    let query = `
      SELECT * FROM casinos 
      WHERE is_active = true 
      AND (name ILIKE $1 OR description ILIKE $1)
    `;
    let params = [`%${q}%`];
    
    if (min_rating) {
      query += ' AND rating >= $' + (params.length + 1);
      params.push(min_rating);
    }
    
    query += ' ORDER BY rating DESC LIMIT 20';
    
    const result = await pool.query(query, params);
    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length,
      query: q
    });
  } catch (err) {
    console.error('Error searching casinos:', err);
    res.status(500).json({ 
      success: false,
      error: 'Search failed',
      message: err.message 
    });
  }
});

// Statistics endpoint
app.get('/api/stats', async (req, res) => {
  try {
    const stats = await Promise.all([
      pool.query('SELECT COUNT(*) as total_casinos FROM casinos WHERE is_active = true'),
      pool.query('SELECT COUNT(*) as featured_casinos FROM casinos WHERE is_featured = true AND is_active = true'),
      pool.query('SELECT COUNT(*) as total_bonuses FROM bonuses WHERE is_active = true'),
      pool.query('SELECT AVG(rating) as avg_rating FROM casinos WHERE is_active = true')
    ]);
    
    res.json({
      success: true,
      data: {
        total_casinos: parseInt(stats[0].rows[0].total_casinos),
        featured_casinos: parseInt(stats[1].rows[0].featured_casinos),
        total_bonuses: parseInt(stats[2].rows[0].total_bonuses),
        average_rating: parseFloat(stats[3].rows[0].avg_rating).toFixed(2)
      }
    });
  } catch (err) {
    console.error('Error fetching stats:', err);
    res.status(500).json({ 
      success: false,
      error: 'Failed to fetch statistics',
      message: err.message 
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    error: 'Internal server error'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found'
  });
});

// Start server
app.listen(port, () => {
  console.log(`🚀 BestCasinoPortal API server running on port ${port}`);
  console.log(`📊 Health check: http://localhost:${port}/health`);
  console.log(`🎰 Casinos API: http://localhost:${port}/api/casinos`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  pool.end(() => {
    console.log('Database pool closed');
    process.exit(0);
  });
});
