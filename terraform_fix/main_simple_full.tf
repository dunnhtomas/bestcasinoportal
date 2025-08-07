# Terraform configuration for Best Casino Portal - Simplified Production Ready
# Professional MCP-Style Infrastructure as Code

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

# A record for root domain (fixed TTL for proxied records)
resource "cloudflare_record" "root" {
  zone_id = data.cloudflare_zone.main.id
  name    = var.domain
  content = var.server_ip
  type    = "A"
  ttl     = 1
  proxied = true
  comment = "Main A record for ${var.project_name} - ${var.environment}"
}

# A record for www subdomain (fixed TTL for proxied records)
resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zone.main.id
  name    = "www"
  content = var.server_ip
  type    = "A"
  ttl     = 1
  proxied = true
  comment = "WWW subdomain A record for ${var.project_name} - ${var.environment}"
}

# Basic caching page rule
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

output "project_info" {
  description = "Project information"
  value = {
    project_name = var.project_name
    environment  = var.environment
    domain      = var.domain
    server_ip   = var.server_ip
  }
}

output "deployment_status" {
  description = "Deployment configuration status"
  value = {
    dns_configured = "✅"
    caching_rules = "✅"
    api_bypass = "✅"
    production_ready = "✅"
  }
}
