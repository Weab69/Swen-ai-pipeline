variable "cloud_provider" {
  description = "Cloud provider to deploy to (aws or alibaba)"
  type        = string
  validation {
    condition     = contains(["aws", "alibaba"], var.cloud_provider)
    error_message = "Cloud provider must be either 'aws' or 'alibaba'."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "swen"
}

variable "region" {
  description = "Region for deployment"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for multi-AZ deployment"
  type        = list(string)
}

# Database Configuration
variable "database_config" {
  description = "Database configuration"
  type = object({
    instance_class    = string
    allocated_storage = number
    engine_version    = string
    multi_az         = bool
  })
  default = {
    instance_class    = "db.t3.micro"
    allocated_storage = 20
    engine_version    = "13.7"
    multi_az         = false
  }
}

# Redis Configuration
variable "redis_config" {
  description = "Redis configuration"
  type = object({
    node_type          = string
    num_cache_nodes    = number
    engine_version     = string
  })
  default = {
    node_type          = "cache.t3.micro"
    num_cache_nodes    = 1
    engine_version     = "7.0"
  }
}

# Container Configuration
variable "container_config" {
  description = "Container configuration for microservices"
  type = object({
    cpu       = number
    memory    = number
    min_count = number
    max_count = number
  })
  default = {
    cpu       = 256
    memory    = 512
    min_count = 1
    max_count = 3
  }
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = ""
}

# Environment Variables
variable "app_env_vars" {
  description = "Environment variables for the application"
  type        = map(string)
  default     = {}
  sensitive   = true
}

# Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
