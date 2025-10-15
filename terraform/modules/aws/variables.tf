variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "database_config" {
  description = "Database configuration"
  type = object({
    instance_class    = string
    allocated_storage = number
    engine_version    = string
    multi_az         = bool
  })
}

variable "redis_config" {
  description = "Redis configuration"
  type = object({
    node_type          = string
    num_cache_nodes    = number
    engine_version     = string
  })
}

variable "container_config" {
  description = "Container configuration"
  type = object({
    cpu       = number
    memory    = number
    min_count = number
    max_count = number
  })
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "app_env_vars" {
  description = "Environment variables for the application"
  type        = map(string)
  sensitive   = true
}

variable "microservices" {
  description = "Microservices configuration"
  type = map(object({
    port = number
    path = string
  }))
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
}
