#!/bin/bash
set -e

echo "🚀 PRODUCTION PERFORMANCE OPTIMIZATION"
echo "======================================"

# System optimization
echo "⚙️ Optimizing system settings..."

# Increase file descriptor limits
echo "fs.file-max = 65536" >> /etc/sysctl.conf
echo "net.core.somaxconn = 65536" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 65536" >> /etc/sysctl.conf

# Apply sysctl changes
sysctl -p

# Optimize PostgreSQL
echo "🗄️ Optimizing PostgreSQL settings..."
docker-compose exec postgres psql -U casino_admin -d bestcasinoportal -c "
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;
SELECT pg_reload_conf();
"

# Optimize Redis
echo "🔴 Optimizing Redis settings..."
docker-compose exec redis redis-cli CONFIG SET maxmemory 256mb
docker-compose exec redis redis-cli CONFIG SET maxmemory-policy allkeys-lru
docker-compose exec redis redis-cli CONFIG SET save "900 1 300 10 60 10000"

# Create database indexes for performance
echo "📊 Creating performance indexes..."
docker-compose exec postgres psql -U casino_admin -d bestcasinoportal -c "
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_casinos_featured_rating ON casinos(is_featured, rating DESC) WHERE is_featured = true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_casinos_active_rating ON casinos(is_active, rating DESC) WHERE is_active = true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_casino_reviews_published ON casino_reviews(casino_id, is_published) WHERE is_published = true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_games_category_popular ON games(category, is_popular) WHERE is_popular = true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bonuses_active_casino ON bonuses(casino_id, is_active) WHERE is_active = true;
ANALYZE;
"

# Enable Nginx micro-caching
echo "⚡ Enabling Nginx micro-caching..."
cat >> /etc/nginx/conf.d/cache.conf << 'EOF'
# Micro-cache configuration
proxy_cache_path /var/cache/nginx/microcache levels=1:2 keys_zone=microcache:10m max_size=500m inactive=60m use_temp_path=off;

# Cache zone for static content
proxy_cache_path /var/cache/nginx/static levels=1:2 keys_zone=staticcache:10m max_size=1g inactive=24h use_temp_path=off;
EOF

# Create cache directories
mkdir -p /var/cache/nginx/microcache
mkdir -p /var/cache/nginx/static
chown -R www-data:www-data /var/cache/nginx

# Restart services to apply optimizations
echo "🔄 Restarting services..."
systemctl reload nginx
docker-compose restart postgres redis

# Run performance tests
echo "🧪 Running performance benchmarks..."
echo "Testing homepage load time..."
curl -w "Time: %{time_total}s\n" -o /dev/null -s https://bestcasinoportal.com

echo "Testing API response time..."
curl -w "Time: %{time_total}s\n" -o /dev/null -s https://bestcasinoportal.com/api/casinos

echo "✅ Performance optimization completed!"
