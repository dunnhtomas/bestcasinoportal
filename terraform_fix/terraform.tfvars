# Terraform Variables for Best Casino Portal
# MCP-Style Configuration Management

cloudflare_token = "pe2L5nDoK0kKvpGVkRSm4P48FExlWfbTZdOZfhXF"
domain = "bestcasinoportal.com"
server_ip = "193.233.161.161"

# Environment configuration
environment = "production"
project_name = "bestcasinoportal"

# SSL/Security settings
ssl_mode = "full"
security_level = "medium"
always_use_https = true
min_tls_version = "1.2"

# Performance settings
enable_brotli = true
enable_minify = true
enable_rocket_loader = true
cache_level = "cache_everything"
edge_cache_ttl = 86400
browser_cache_ttl = 86400

# Rate limiting
rate_limit_threshold = 100
rate_limit_period = 60

# Monitoring
enable_analytics = true
enable_logs = true
log_retention_days = 30
