# AWS Development Environment Configuration
cloud_provider = "aws"
environment = "dev"
project_name = "swen"
region = "us-west-2"

availability_zones = [
  "us-west-2a",
  "us-west-2b"
]

# Database Configuration - Small instance for development
database_config = {
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  engine_version    = "13.7"
  multi_az         = false
}

# Redis Configuration - Small instance for development
redis_config = {
  node_type          = "cache.t3.micro"
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
