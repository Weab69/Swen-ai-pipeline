terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.200"
    }
  }
}

# Local values for common configurations
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = merge(var.common_tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  # Microservices configuration
  microservices = {
    news = {
      port = 3001
      path = "/news"
    }
    storage = {
      port = 3002  
      path = "/storage"
    }
    ai = {
      port = 3003
      path = "/ai"
    }
    ingestion = {
      port = 3004
      path = "/ingestion"
    }
  }
}

# Conditional provider configuration
provider "aws" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  region = var.region
  
  default_tags {
    tags = local.common_tags
  }
}

provider "alicloud" {
  count  = var.cloud_provider == "alibaba" ? 1 : 0
  region = var.region
}

# AWS Infrastructure
module "aws_infrastructure" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/aws"

  providers = {
    aws = aws[0]
  }

  project_name        = var.project_name
  environment         = var.environment
  region              = var.region
  availability_zones  = var.availability_zones
  database_config     = var.database_config
  redis_config        = var.redis_config
  container_config    = var.container_config
  domain_name         = var.domain_name
  app_env_vars        = var.app_env_vars
  microservices       = local.microservices
  common_tags         = local.common_tags
}

# Alibaba Cloud Infrastructure  
module "alibaba_infrastructure" {
  count  = var.cloud_provider == "alibaba" ? 1 : 0
  source = "./modules/alibaba"

  providers = {
    alicloud = alicloud[0]
  }

  project_name        = var.project_name
  environment         = var.environment
  region              = var.region
  availability_zones  = var.availability_zones
  database_config     = var.database_config
  redis_config        = var.redis_config
  container_config    = var.container_config
  domain_name         = var.domain_name
  app_env_vars        = var.app_env_vars
  microservices       = local.microservices
  common_tags         = local.common_tags
}
