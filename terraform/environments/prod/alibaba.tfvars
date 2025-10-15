# Alibaba Cloud Production Environment Configuration
cloud_provider = "alibaba"
environment = "prod"
project_name = "swen"
region = "cn-beijing"

availability_zones = [
  "cn-beijing-a",
  "cn-beijing-f",
  "cn-beijing-g"
]

# Database Configuration - High availability for production
database_config = {
  instance_class    = "postgres.n4.large.1"
  allocated_storage = 100
  engine_version    = "13.0"
  multi_az         = true
}

# Redis Configuration - High availability for production
redis_config = {
  node_type          = "redis.shard.large.default"
  num_cache_nodes    = 3
  engine_version     = "7.0"
}

# Container Configuration - Production-ready scaling
container_config = {
  cpu       = 1024
  memory    = 2048
  min_count = 2
  max_count = 10
}

# Domain name for production
domain_name = "your-domain.com"

# Common tags
common_tags = {
  Environment = "production"
  Team        = "engineering"
  CostCenter  = "production"
  Backup     = "required"
  Monitoring = "enabled"
}
