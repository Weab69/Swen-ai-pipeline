# AWS Production Environment Configuration
cloud_provider = "aws"
environment = "prod"
project_name = "swen"
region = "us-east-1"

availability_zones = [
  "us-east-1a",
  "us-east-1b",
  "us-east-1c"
]

# Database Configuration - High availability for production
database_config = {
  instance_class    = "db.r5.large"
  allocated_storage = 100
  engine_version    = "13.7"
  multi_az         = true
}

# Redis Configuration - High availability for production
redis_config = {
  node_type          = "cache.r5.large"
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
