# Terraform configuration for Best Casino Portal
# Professional MCP-Style Infrastructure as Code with Full Variable Support

terraform {
  required_version = ">= 1.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Configure the Cloudflare Provider
provider "cloudflare" {
  api_token = var.cloudflare_token
}

# Data source to get the zone
data "cloudflare_zone" "main" {
  name = var.domain
}

# A record for root domain
resource "cloudflare_record" "root" {
  zone_id = data.cloudflare_zone.main.id
  name    = var.domain
  value   = var.server_ip
  type    = "A"
  ttl     = 300
  proxied = true
  comment = "Main A record for ${var.project_name} - ${var.environment}"
}

# A record for www subdomain
resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zone.main.id
  name    = "www"
  value   = var.server_ip
  type    = "A"
  ttl     = 300
  proxied = true
  comment = "WWW subdomain A record for ${var.project_name} - ${var.environment}"
}

# SSL/TLS settings using variables
resource "cloudflare_zone_settings_override" "ssl_settings" {
  zone_id = data.cloudflare_zone.main.id
  settings {
    ssl                      = var.ssl_mode
    always_use_https        = var.always_use_https ? "on" : "off"
    min_tls_version         = var.min_tls_version
    tls_1_3                 = "on"
    automatic_https_rewrites = "on"
    universal_ssl           = "on"
  }
}

# Security settings using variables
resource "cloudflare_zone_settings_override" "security_settings" {
  zone_id = data.cloudflare_zone.main.id
  settings {
    security_level      = var.security_level
    challenge_ttl       = 1800
    browser_check       = "on"
    hotlink_protection  = "on"
  }
}

# Performance settings using variables
resource "cloudflare_zone_settings_override" "performance_settings" {
  zone_id = data.cloudflare_zone.main.id
  settings {
    brotli = var.enable_brotli ? "on" : "off"
    minify {
      css  = var.enable_minify ? "on" : "off"
      js   = var.enable_minify ? "on" : "off"
      html = var.enable_minify ? "on" : "off"
    }
    rocket_loader = var.enable_rocket_loader ? "on" : "off"
    mirage        = "on"
    polish        = "lossless"
  }
}

# Caching rules using variables
resource "cloudflare_page_rule" "cache_everything" {
  zone_id  = data.cloudflare_zone.main.id
  target   = "${var.domain}/*"
  priority = 1
  status   = "active"

  actions {
    cache_level         = var.cache_level
    edge_cache_ttl     = var.edge_cache_ttl
    browser_cache_ttl  = var.browser_cache_ttl
  }
}

# Page rule for API endpoints (cache bypass)
resource "cloudflare_page_rule" "api_bypass" {
  zone_id  = data.cloudflare_zone.main.id
  target   = "${var.domain}/api/*"
  priority = 2
  status   = "active"

  actions {
    cache_level = "bypass"
  }
}

# WAF managed ruleset
resource "cloudflare_ruleset" "waf" {
  zone_id     = data.cloudflare_zone.main.id
  name        = "${var.project_name} WAF - ${var.environment}"
  description = "WAF rules for ${var.domain} (${var.environment})"
  kind        = "zone"
  phase       = "http_request_firewall_managed"

  rules {
    action      = "managed_challenge"
    expression  = "(cf.threat_score gt 14)"
    description = "Challenge suspicious traffic"
    enabled     = true
  }
}

# Rate limiting rule using variables
resource "cloudflare_rate_limit" "api_limit" {
  zone_id   = data.cloudflare_zone.main.id
  threshold = var.rate_limit_threshold
  period    = var.rate_limit_period
  action {
    mode    = "challenge"
    timeout = 86400
  }
  match {
    request {
      url_pattern = "${var.domain}/api/*"
      schemes     = ["HTTP", "HTTPS"]
      methods     = ["GET", "POST", "PUT", "DELETE"]
    }
  }
  disabled    = false
  description = "Rate limit API requests - ${var.environment}"
}

# Rate limiting rule for login
resource "cloudflare_rate_limit" "login_limit" {
  zone_id   = data.cloudflare_zone.main.id
  threshold = 5
  period    = 60
  action {
    mode    = "challenge"
    timeout = 86400
  }
  match {
    request {
      url_pattern = "${var.domain}/login*"
      schemes     = ["HTTP", "HTTPS"]
      methods     = ["POST"]
    }
  }
  disabled    = false
  description = "Rate limit login attempts - ${var.environment}"
}

# Custom SSL certificate (conditional on environment)
resource "cloudflare_certificate_pack" "advanced_certificate" {
  count                 = var.environment == "production" ? 1 : 0
  zone_id               = data.cloudflare_zone.main.id
  type                  = "advanced"
  hosts                 = [var.domain, "www.${var.domain}"]
  validation_method     = "txt"
  validity_days         = 90
  certificate_authority = "lets_encrypt"
  cloudflare_branding   = false
}

# Logpush job (conditional on enable_logs)
resource "cloudflare_logpush_job" "http_requests" {
  count                = var.enable_logs ? 1 : 0
  zone_id              = data.cloudflare_zone.main.id
  name                 = "${var.project_name}-http-requests-${var.environment}"
  logpull_options      = "fields=ClientIP,ClientRequestHost,ClientRequestMethod,ClientRequestURI,EdgeEndTimestamp,EdgeResponseBytes,EdgeResponseStatus,EdgeStartTimestamp,RayID&timestamps=rfc3339"
  destination_conf     = "s3://cloudflare-logs-${var.project_name}/http_requests/{DATE}?region=us-east-1"
  dataset              = "http_requests"
  enabled              = true
  frequency            = "high"
  max_upload_bytes     = 5000000
  max_upload_interval  = 30
  max_upload_records   = 1000
}

# Outputs
output "zone_id" {
  description = "Cloudflare Zone ID"
  value       = data.cloudflare_zone.main.id
}

output "nameservers" {
  description = "Cloudflare nameservers"
  value       = data.cloudflare_zone.main.name_servers
}

output "root_record_id" {
  description = "Root A record ID"
  value       = cloudflare_record.root.id
}

output "www_record_id" {
  description = "WWW A record ID"  
  value       = cloudflare_record.www.id
}

output "ssl_status" {
  description = "SSL configuration status"
  value       = cloudflare_zone_settings_override.ssl_settings.settings[0].ssl
}

output "project_info" {
  description = "Project information"
  value = {
    project_name = var.project_name
    environment  = var.environment
    domain      = var.domain
    server_ip   = var.server_ip
  }
}

output "security_config" {
  description = "Security configuration summary"
  value = {
    ssl_mode         = var.ssl_mode
    security_level   = var.security_level
    always_use_https = var.always_use_https
    min_tls_version  = var.min_tls_version
  }
}

output "performance_config" {
  description = "Performance configuration summary"
  value = {
    enable_brotli       = var.enable_brotli
    enable_minify       = var.enable_minify
    enable_rocket_loader = var.enable_rocket_loader
    cache_level         = var.cache_level
    edge_cache_ttl      = var.edge_cache_ttl
    browser_cache_ttl   = var.browser_cache_ttl
  }
}
