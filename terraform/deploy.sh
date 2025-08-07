#!/bin/bash

# Terraform deployment script for bestcasinoportal.com
# Run this after setting up Cloudflare API token and Zone ID

echo "🚀 BestCasinoPortal Terraform Deployment"
echo "========================================"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ ERROR: terraform.tfvars not found!"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and fill in your values."
    exit 1
fi

# Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init

# Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📋 Planning deployment..."
terraform plan

# Apply with confirmation
echo "🚀 Applying Terraform configuration..."
read -p "Do you want to apply these changes? (y/N): " -n 1 -r
echo
if [[  =~ ^[Yy]$ ]]; then
    terraform apply
    echo "✅ Deployment complete!"
    echo "🌐 Your domain is now configured with Cloudflare"
    terraform output
else
    echo "❌ Deployment cancelled"
fi
