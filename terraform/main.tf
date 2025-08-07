terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
  
  backend "local" {
    path = "terraform.tfstate"
  }
}

# Configure Cloudflare Provider
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Variables
variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "zone_id" {
  description = "Cloudflare Zone ID for bestcasinoportal.com"
  type        = string
}

variable "domain" {
  description = "Domain name"
  type        = string
  default     = "bestcasinoportal.com"
}

variable "server_ip" {
  description = "Server IP address"
  type        = string
  default     = "193.233.161.161"
}

# DNS Records
resource "cloudflare_record" "root" {
  zone_id = var.zone_id
  name    = "@"
  value   = var.server_ip
  type    = "A"
  ttl     = 300
  proxied = true
  comment = "Root domain pointing to production server"
}

resource "cloudflare_record" "www" {
  zone_id = var.zone_id
  name    = "www"
  value   = var.domain
  type    = "CNAME"
  ttl     = 300
  proxied = true
  comment = "WWW subdomain"
}

resource "cloudflare_record" "api" {
  zone_id = var.zone_id
  name    = "api"
  value   = var.server_ip
  type    = "A"
  ttl     = 300
  proxied = true
  comment = "API subdomain"
}

# Page Rules for SEO and Performance
resource "cloudflare_page_rule" "cache_everything" {
  zone_id  = var.zone_id
  target   = "/*"
  priority = 1
  status   = "active"

  actions {
    cache_level = "cache_everything"
    edge_cache_ttl = 7200
    browser_cache_ttl = 3600
  }
}

resource "cloudflare_page_rule" "api_bypass_cache" {
  zone_id  = var.zone_id
  target   = "api./*"
  priority = 2
  status   = "active"

  actions {
    cache_level = "bypass"
  }
}

# SSL/TLS Settings
resource "cloudflare_zone_settings_override" "ssl_settings" {
  zone_id = var.zone_id
  
  settings {
    ssl = "full"
    always_use_https = "on"
    automatic_https_rewrites = "on"
    security_level = "medium"
    brotli = "on"
    minify {
      css  = "on"
      js   = "on"
      html = "on"
    }
  }
}

# Outputs
output "dns_records" {
  description = "Created DNS records"
  value = {
    root = cloudflare_record.root.hostname
    www  = cloudflare_record.www.hostname
    api  = cloudflare_record.api.hostname
  }
}

output "ssl_status" {
  description = "SSL/TLS configuration status"
  value = "Full SSL enabled with automatic HTTPS rewrites"
}
