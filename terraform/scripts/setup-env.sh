#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
CLOUD_PROVIDER=""
ENVIRONMENT=""

# Function to print usage
usage() {
    echo "Usage: $0 -c <cloud_provider> -e <environment>"
    echo ""
    echo "Required arguments:"
    echo "  -c, --cloud-provider  Cloud provider (aws|alibaba)"
    echo "  -e, --environment     Environment (dev|staging|prod)"
    echo ""
    echo "This script helps you set up environment variables for the SWEN application deployment."
    echo ""
    echo "Examples:"
    echo "  $0 -c aws -e dev"
    echo "  $0 -c alibaba -e prod"
    exit 1
}

# Function to validate inputs
validate_inputs() {
    if [[ ! "$CLOUD_PROVIDER" =~ ^(aws|alibaba)$ ]]; then
        echo -e "${RED}Error: Cloud provider must be 'aws' or 'alibaba'${NC}"
        exit 1
    fi

    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        echo -e "${RED}Error: Environment must be 'dev', 'staging', or 'prod'${NC}"
        exit 1
    fi
}

# Function to setup AWS environment
setup_aws_env() {
    echo -e "${YELLOW}Setting up AWS environment variables for $ENVIRONMENT...${NC}"
    
    # Check if AWS credentials are configured
    if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
        echo -e "${YELLOW}AWS credentials not found in environment variables.${NC}"
        echo -e "${YELLOW}Please configure AWS credentials using one of the following methods:${NC}"
        echo ""
        echo "1. AWS CLI:"
        echo "   aws configure"
        echo ""
        echo "2. Environment variables:"
        echo "   export AWS_ACCESS_KEY_ID=your_access_key"
        echo "   export AWS_SECRET_ACCESS_KEY=your_secret_key"
        echo "   export AWS_DEFAULT_REGION=us-west-2"
        echo ""
        echo "3. IAM roles (if running on EC2)"
        echo ""
        read -p "Have you configured AWS credentials? (y/n): " configured
        if [[ "$configured" != "y" ]]; then
            echo -e "${RED}Please configure AWS credentials before proceeding.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ AWS credentials found${NC}"
    fi

    # Create environment variables for the application
    cat > ".env.${ENVIRONMENT}" << EOF
# SWEN Application Configuration - AWS ${ENVIRONMENT^^}
NODE_ENV=${ENVIRONMENT}
CLOUD_PROVIDER=aws

# Database Configuration (will be populated after Terraform deployment)
# DATABASE_URL=postgresql://username:password@endpoint:5432/swen
# DATABASE_HOST=
# DATABASE_PORT=5432
# DATABASE_NAME=swen
# DATABASE_USER=postgres

# Redis Configuration (will be populated after Terraform deployment)
# REDIS_HOST=
# REDIS_PORT=6379

# Application Configuration
PORT=3000

# External API Keys (replace with your actual keys)
OPENAI_API_KEY=${OPENAI_API_KEY:-your_openai_api_key_here}
NEWS_API_KEY=${NEWS_API_KEY:-your_news_api_key_here}

# Supabase Configuration (if using)
SUPABASE_URL=${SUPABASE_URL:-your_supabase_url_here}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-your_supabase_anon_key_here}

# Logging
LOG_LEVEL=${LOG_LEVEL:-info}

# Security
JWT_SECRET=${JWT_SECRET:-your_jwt_secret_here}

EOF

    echo -e "${GREEN}✓ Environment file created: .env.${ENVIRONMENT}${NC}"
    echo -e "${YELLOW}Please update the API keys and other sensitive values in .env.${ENVIRONMENT}${NC}"
}

# Function to setup Alibaba Cloud environment
setup_alibaba_env() {
    echo -e "${YELLOW}Setting up Alibaba Cloud environment variables for $ENVIRONMENT...${NC}"
    
    # Check if Alibaba Cloud credentials are configured
    if [[ -z "$ALICLOUD_ACCESS_KEY" || -z "$ALICLOUD_SECRET_KEY" ]]; then
        echo -e "${YELLOW}Alibaba Cloud credentials not found in environment variables.${NC}"
        echo -e "${YELLOW}Please configure Alibaba Cloud credentials:${NC}"
        echo ""
        echo "1. Environment variables:"
        echo "   export ALICLOUD_ACCESS_KEY=your_access_key"
        echo "   export ALICLOUD_SECRET_KEY=your_secret_key"
        echo "   export ALICLOUD_REGION=cn-hangzhou"
        echo ""
        echo "2. Alibaba Cloud CLI (if installed):"
        echo "   aliyun configure"
        echo ""
        read -p "Have you configured Alibaba Cloud credentials? (y/n): " configured
        if [[ "$configured" != "y" ]]; then
            echo -e "${RED}Please configure Alibaba Cloud credentials before proceeding.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Alibaba Cloud credentials found${NC}"
    fi

    # Create environment variables for the application
    cat > ".env.${ENVIRONMENT}" << EOF
# SWEN Application Configuration - Alibaba Cloud ${ENVIRONMENT^^}
NODE_ENV=${ENVIRONMENT}
CLOUD_PROVIDER=alibaba

# Database Configuration (will be populated after Terraform deployment)
# DATABASE_URL=postgresql://username:password@endpoint:5432/swen
# DATABASE_HOST=
# DATABASE_PORT=5432
# DATABASE_NAME=swen
# DATABASE_USER=postgres

# Redis Configuration (will be populated after Terraform deployment)
# REDIS_HOST=
# REDIS_PORT=6379

# Application Configuration
PORT=3000

# External API Keys (replace with your actual keys)
OPENAI_API_KEY=${OPENAI_API_KEY:-your_openai_api_key_here}
NEWS_API_KEY=${NEWS_API_KEY:-your_news_api_key_here}

# Supabase Configuration (if using)
SUPABASE_URL=${SUPABASE_URL:-your_supabase_url_here}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-your_supabase_anon_key_here}

# Logging
LOG_LEVEL=${LOG_LEVEL:-info}

# Security
JWT_SECRET=${JWT_SECRET:-your_jwt_secret_here}

EOF

    echo -e "${GREEN}✓ Environment file created: .env.${ENVIRONMENT}${NC}"
    echo -e "${YELLOW}Please update the API keys and other sensitive values in .env.${ENVIRONMENT}${NC}"
}

# Function to update env file with Terraform outputs
update_env_with_terraform() {
    echo -e "${YELLOW}Attempting to update .env.${ENVIRONMENT} with Terraform outputs...${NC}"
    
    TERRAFORM_DIR="$(dirname "$0")/.."
    cd "$TERRAFORM_DIR"
    
    # Check if Terraform state exists
    if [[ ! -f "terraform.tfstate" ]]; then
        echo -e "${YELLOW}No Terraform state found. Run terraform apply first.${NC}"
        return 0
    fi
    
    # Get outputs
    DATABASE_ENDPOINT=$(terraform output -raw database_endpoint 2>/dev/null || echo "")
    REDIS_ENDPOINT=$(terraform output -raw redis_endpoint 2>/dev/null || echo "")
    LOAD_BALANCER_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "")
    
    # Update the environment file
    if [[ -n "$DATABASE_ENDPOINT" && "$DATABASE_ENDPOINT" != "null" ]]; then
        sed -i "s|# DATABASE_HOST=.*|DATABASE_HOST=${DATABASE_ENDPOINT}|g" "../.env.${ENVIRONMENT}"
        echo -e "${GREEN}✓ Updated DATABASE_HOST${NC}"
    fi
    
    if [[ -n "$REDIS_ENDPOINT" && "$REDIS_ENDPOINT" != "null" ]]; then
        sed -i "s|# REDIS_HOST=.*|REDIS_HOST=${REDIS_ENDPOINT}|g" "../.env.${ENVIRONMENT}"
        echo -e "${GREEN}✓ Updated REDIS_HOST${NC}"
    fi
    
    if [[ -n "$LOAD_BALANCER_DNS" && "$LOAD_BALANCER_DNS" != "null" ]]; then
        echo "# Load Balancer DNS: ${LOAD_BALANCER_DNS}" >> "../.env.${ENVIRONMENT}"
        echo -e "${GREEN}✓ Added load balancer DNS${NC}"
    fi
}

# Function to create Terraform variable file for app_env_vars
create_terraform_env_vars() {
    echo -e "${YELLOW}Creating Terraform environment variables file...${NC}"
    
    TERRAFORM_DIR="$(dirname "$0")/.."
    
    cat > "$TERRAFORM_DIR/environments/$ENVIRONMENT/app-env-vars.auto.tfvars" << EOF
# Application Environment Variables for ${ENVIRONMENT}
# This file is automatically generated and contains sensitive data
# DO NOT commit this file to version control

app_env_vars = {
  NODE_ENV    = "${ENVIRONMENT}"
  CLOUD_PROVIDER = "${CLOUD_PROVIDER}"
  PORT        = "3000"
  LOG_LEVEL   = "${LOG_LEVEL:-info}"
  
  # External API Keys - Update these with your actual keys
  OPENAI_API_KEY = "${OPENAI_API_KEY:-your_openai_api_key_here}"
  NEWS_API_KEY   = "${NEWS_API_KEY:-your_news_api_key_here}"
  
  # Supabase Configuration
  SUPABASE_URL      = "${SUPABASE_URL:-your_supabase_url_here}"
  SUPABASE_ANON_KEY = "${SUPABASE_ANON_KEY:-your_supabase_anon_key_here}"
  
  # Security
  JWT_SECRET = "${JWT_SECRET:-your_jwt_secret_here}"
}
EOF

    echo -e "${GREEN}✓ Created Terraform environment variables file: environments/$ENVIRONMENT/app-env-vars.auto.tfvars${NC}"
    echo -e "${YELLOW}Please update the API keys and secrets in this file${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--cloud-provider)
            CLOUD_PROVIDER="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Check if required arguments are provided
if [[ -z "$CLOUD_PROVIDER" || -z "$ENVIRONMENT" ]]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    usage
fi

# Main execution
echo -e "${GREEN}=== Environment Setup Script ===${NC}"
echo -e "${YELLOW}Cloud Provider: $CLOUD_PROVIDER${NC}"
echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
echo ""

validate_inputs

# Setup cloud-specific environment
if [[ "$CLOUD_PROVIDER" == "aws" ]]; then
    setup_aws_env
elif [[ "$CLOUD_PROVIDER" == "alibaba" ]]; then
    setup_alibaba_env
fi

# Create Terraform variables file
create_terraform_env_vars

# Try to update with Terraform outputs if available
update_env_with_terraform

echo ""
echo -e "${GREEN}=== Environment setup completed ===${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review and update API keys in .env.${ENVIRONMENT}"
echo "2. Review and update secrets in environments/$ENVIRONMENT/app-env-vars.auto.tfvars"
echo "3. Run terraform plan/apply to create infrastructure"
echo "4. Run the setup script again to populate infrastructure endpoints"
