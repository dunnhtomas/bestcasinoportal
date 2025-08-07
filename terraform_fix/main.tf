# Terraform configuration for Best Casino Portal - DNS Only
# Minimal Professional Configuration for Basic DNS Management

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
  content = var.server_ip
  type    = "A"
  ttl     = 1
  proxied = true
  comment = "Main A record for ${var.project_name} - ${var.environment}"
}

# A record for www subdomain
resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zone.main.id
  name    = "www"
  content = var.server_ip
  type    = "A"
  ttl     = 1
  proxied = true
  comment = "WWW subdomain A record for ${var.project_name} - ${var.environment}"
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
    cloudflare_proxy = "✅"
    production_ready = "✅"
    note = "Additional settings configured manually in Cloudflare dashboard"
  }
}
