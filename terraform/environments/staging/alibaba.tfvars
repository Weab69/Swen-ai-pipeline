# Alibaba Cloud Staging Environment Configuration
cloud_provider = "alibaba"
environment = "staging"
project_name = "swen"
region = "cn-shanghai"

availability_zones = [
  "cn-shanghai-a",
  "cn-shanghai-b"
]

# Database Configuration - Mid-tier for staging
database_config = {
  instance_class    = "postgres.n2.medium.1"
  allocated_storage = 50
  engine_version    = "13.0"
  multi_az         = true
}

# Redis Configuration - Mid-tier for staging
redis_config = {
  node_type          = "redis.shard.medium.default"
  num_cache_nodes    = 1
  engine_version     = "7.0"
}

# Container Configuration - Staging resources
container_config = {
  cpu       = 512
  memory    = 1024
  min_count = 1
  max_count = 5
}

# Domain name for staging
domain_name = "staging.your-domain.com"

# Common tags
common_tags = {
  Environment = "staging"
  Team        = "engineering"
  CostCenter  = "staging"
  Monitoring = "enabled"
}
