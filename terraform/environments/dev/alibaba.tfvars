# Alibaba Cloud Development Environment Configuration
cloud_provider = "alibaba"
environment = "dev"
project_name = "swen"
region = "cn-hangzhou"

availability_zones = [
  "cn-hangzhou-g",
  "cn-hangzhou-h"
]

# Database Configuration - Small instance for development
database_config = {
  instance_class    = "postgres.n2.small.1"
  allocated_storage = 20
  engine_version    = "13.0"
  multi_az         = false
}

# Redis Configuration - Small instance for development
redis_config = {
  node_type          = "redis.shard.small.default"
  num_cache_nodes    = 1
  engine_version     = "7.0"
}

# Container Configuration - Minimal resources for development
container_config = {
  cpu       = 256
  memory    = 512
  min_count = 1
  max_count = 2
}

# Domain name (optional for dev)
domain_name = ""

# Common tags
common_tags = {
  Environment = "development"
  Team        = "engineering"
  CostCenter  = "development"
}
