# Terraform Variables Definition
# Professional MCP-Style Infrastructure as Code

# Core configuration
variable "cloudflare_token" {
  description = "Cloudflare API token for authentication"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Primary domain name"
  type        = string
}

variable "server_ip" {
  description = "Server IP address"
  type        = string
}

# Environment configuration
variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "bestcasinoportal"
}

# SSL/Security settings
variable "ssl_mode" {
  description = "SSL mode for Cloudflare"
  type        = string
  default     = "full"
  validation {
    condition     = contains(["off", "flexible", "full", "strict"], var.ssl_mode)
    error_message = "SSL mode must be one of: off, flexible, full, strict."
  }
}

variable "security_level" {
  description = "Security level for Cloudflare"
  type        = string
  default     = "medium"
  validation {
    condition     = contains(["essentially_off", "low", "medium", "high", "under_attack"], var.security_level)
    error_message = "Security level must be one of: essentially_off, low, medium, high, under_attack."
  }
}

variable "always_use_https" {
  description = "Enable Always Use HTTPS"
  type        = bool
  default     = true
}

variable "min_tls_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "1.2"
  validation {
    condition     = contains(["1.0", "1.1", "1.2", "1.3"], var.min_tls_version)
    error_message = "Min TLS version must be one of: 1.0, 1.1, 1.2, 1.3."
  }
}

# Performance settings
variable "enable_brotli" {
  description = "Enable Brotli compression"
  type        = bool
  default     = true
}

variable "enable_minify" {
  description = "Enable CSS/JS/HTML minification"
  type        = bool
  default     = true
}

variable "enable_rocket_loader" {
  description = "Enable Rocket Loader for JavaScript optimization"
  type        = bool
  default     = true
}

variable "cache_level" {
  description = "Cache level for page rules"
  type        = string
  default     = "cache_everything"
  validation {
    condition     = contains(["bypass", "basic", "simplified", "aggressive", "cache_everything"], var.cache_level)
    error_message = "Cache level must be one of: bypass, basic, simplified, aggressive, cache_everything."
  }
}

variable "edge_cache_ttl" {
  description = "Edge cache TTL in seconds"
  type        = number
  default     = 86400
}

variable "browser_cache_ttl" {
  description = "Browser cache TTL in seconds"
  type        = number
  default     = 86400
}

# Rate limiting
variable "rate_limit_threshold" {
  description = "Rate limit threshold (requests per period)"
  type        = number
  default     = 100
}

variable "rate_limit_period" {
  description = "Rate limit period in seconds"
  type        = number
  default     = 60
}

# Monitoring
variable "enable_analytics" {
  description = "Enable Cloudflare Analytics"
  type        = bool
  default     = true
}

variable "enable_logs" {
  description = "Enable Cloudflare Logs"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 30
}
