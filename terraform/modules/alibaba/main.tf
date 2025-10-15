terraform {
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.200"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# VPC and Networking
resource "alicloud_vpc" "main" {
  vpc_name   = "${local.name_prefix}-vpc"
  cidr_block = "10.0.0.0/16"

  tags = var.common_tags
}

resource "alicloud_vswitch" "public" {
  count = length(var.availability_zones)

  vpc_id       = alicloud_vpc.main.id
  cidr_block   = "10.0.${count.index + 1}.0/24"
  zone_id      = var.availability_zones[count.index]
  vswitch_name = "${local.name_prefix}-public-${count.index + 1}"

  tags = merge(var.common_tags, {
    Type = "Public"
  })
}

resource "alicloud_vswitch" "private" {
  count = length(var.availability_zones)

  vpc_id       = alicloud_vpc.main.id
  cidr_block   = "10.0.${count.index + 10}.0/24"
  zone_id      = var.availability_zones[count.index]
  vswitch_name = "${local.name_prefix}-private-${count.index + 1}"

  tags = merge(var.common_tags, {
    Type = "Private"
  })
}

# NAT Gateway
resource "alicloud_nat_gateway" "main" {
  vpc_id               = alicloud_vpc.main.id
  nat_gateway_name     = "${local.name_prefix}-nat"
  payment_type         = "PayAsYouGo"
  vswitch_id          = alicloud_vswitch.public[0].id
  nat_type            = "Enhanced"

  tags = var.common_tags
}

resource "alicloud_eip_address" "nat" {
  address_name         = "${local.name_prefix}-nat-eip"
  payment_type         = "PayAsYouGo"
  internet_charge_type = "PayByTraffic"
  bandwidth            = "10"

  tags = var.common_tags
}

resource "alicloud_eip_association" "nat" {
  allocation_id = alicloud_eip_address.nat.id
  instance_id   = alicloud_nat_gateway.main.id
}

resource "alicloud_snat_entry" "private" {
  count = length(alicloud_vswitch.private)

  depends_on        = [alicloud_eip_association.nat]
  snat_table_id     = alicloud_nat_gateway.main.snat_table_ids
  source_vswitch_id = alicloud_vswitch.private[count.index].id
  snat_ip           = alicloud_eip_address.nat.ip_address
}

# Security Groups
resource "alicloud_security_group" "slb" {
  name   = "${local.name_prefix}-slb-sg"
  vpc_id = alicloud_vpc.main.id

  tags = var.common_tags
}

resource "alicloud_security_group_rule" "slb_http_in" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "80/80"
  priority          = 1
  security_group_id = alicloud_security_group.slb.id
  cidr_ip          = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "slb_https_in" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "443/443"
  priority          = 1
  security_group_id = alicloud_security_group.slb.id
  cidr_ip          = "0.0.0.0/0"
}

resource "alicloud_security_group" "ecs_service" {
  name   = "${local.name_prefix}-ecs-sg"
  vpc_id = alicloud_vpc.main.id

  tags = var.common_tags
}

resource "alicloud_security_group_rule" "ecs_app_in" {
  type                     = "ingress"
  ip_protocol              = "tcp"
  nic_type                 = "intranet"
  policy                   = "accept"
  port_range               = "3000/3000"
  priority                 = 1
  security_group_id        = alicloud_security_group.ecs_service.id
  source_security_group_id = alicloud_security_group.slb.id
}

resource "alicloud_security_group_rule" "ecs_outbound" {
  type              = "egress"
  ip_protocol       = "all"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "-1/-1"
  priority          = 1
  security_group_id = alicloud_security_group.ecs_service.id
  cidr_ip          = "0.0.0.0/0"
}

resource "alicloud_security_group" "database" {
  name   = "${local.name_prefix}-db-sg"
  vpc_id = alicloud_vpc.main.id

  tags = var.common_tags
}

resource "alicloud_security_group_rule" "db_postgres_in" {
  type                     = "ingress"
  ip_protocol              = "tcp"
  nic_type                 = "intranet"
  policy                   = "accept"
  port_range               = "5432/5432"
  priority                 = 1
  security_group_id        = alicloud_security_group.database.id
  source_security_group_id = alicloud_security_group.ecs_service.id
}

resource "alicloud_security_group" "redis" {
  name   = "${local.name_prefix}-redis-sg"
  vpc_id = alicloud_vpc.main.id

  tags = var.common_tags
}

resource "alicloud_security_group_rule" "redis_in" {
  type                     = "ingress"
  ip_protocol              = "tcp"
  nic_type                 = "intranet"
  policy                   = "accept"
  port_range               = "6379/6379"
  priority                 = 1
  security_group_id        = alicloud_security_group.redis.id
  source_security_group_id = alicloud_security_group.ecs_service.id
}

# Server Load Balancer (SLB)
resource "alicloud_slb_load_balancer" "main" {
  load_balancer_name   = "${local.name_prefix}-slb"
  vswitch_id          = alicloud_vswitch.public[0].id
  load_balancer_spec  = "slb.s1.small"
  internet            = true
  internet_charge_type = "PayByTraffic"

  tags = var.common_tags
}

# Container Registry (ACR)
resource "alicloud_cr_namespace" "main" {
  name               = "${var.project_name}-${var.environment}"
  auto_create        = false
  default_visibility = "PRIVATE"
}

resource "alicloud_cr_repo" "app" {
  namespace = alicloud_cr_namespace.main.name
  name      = "app"
  summary   = "Application repository for ${var.project_name}"
  repo_type = "PRIVATE"
}

# ECS Cluster
resource "alicloud_cs_kubernetes_cluster" "main" {
  name                 = "${local.name_prefix}-cluster"
  cluster_spec         = "ack.pro.small"
  version              = "1.24.6-aliyun.1"
  new_nat_gateway      = false
  node_cidr_mask       = 25
  proxy_mode           = "ipvs"
  service_cidr         = "172.21.0.0/20"
  pod_cidr             = "172.20.0.0/16"
  password             = "Terraform123!"
  install_cloud_monitor = true

  # Control plane configuration
  master_vswitch_ids = alicloud_vswitch.private[*].id
  master_instance_types = ["ecs.n4.large"]
  master_disk_category = "cloud_efficiency"
  master_disk_size = 40

  # Worker node configuration  
  worker_vswitch_ids = alicloud_vswitch.private[*].id
  worker_instance_types = ["ecs.n4.large"]
  worker_disk_category = "cloud_efficiency"
  worker_disk_size = 40
  worker_number = var.container_config.min_count
  worker_data_disks {
    size     = 40
    category = "cloud_efficiency"
  }

  depends_on = [
    alicloud_nat_gateway.main,
    alicloud_snat_entry.private
  ]

  tags = var.common_tags
}

# Node Pool for auto scaling
resource "alicloud_cs_kubernetes_node_pool" "default" {
  cluster_id     = alicloud_cs_kubernetes_cluster.main.id
  node_pool_name = "${local.name_prefix}-nodepool"
  vswitch_ids    = alicloud_vswitch.private[*].id

  scaling_config {
    min_size     = var.container_config.min_count
    max_size     = var.container_config.max_count
    type         = "cpu"
    is_bond_eip  = false
  }

  instance_types = ["ecs.n4.large"]
  system_disk_category = "cloud_efficiency"
  system_disk_size = 40
  install_cloud_monitor = true

  data_disks {
    category = "cloud_efficiency"
    size     = 40
  }

  tags = var.common_tags
}

# RDS Database
resource "alicloud_db_instance" "main" {
  engine               = "PostgreSQL"
  engine_version       = var.database_config.engine_version
  instance_type        = var.database_config.instance_class
  instance_storage     = var.database_config.allocated_storage
  instance_name        = "${local.name_prefix}-database"
  vswitch_id          = alicloud_vswitch.private[0].id
  security_group_ids   = [alicloud_security_group.database.id]
  
  # Multi-AZ configuration
  zone_id             = var.availability_zones[0]
  zone_id_slave_a     = var.database_config.multi_az ? var.availability_zones[1] : null
  
  db_instance_storage_type = "cloud_essd"
  storage_auto_scale   = "Enable"
  storage_threshold    = 30
  storage_upper_bound  = 1000
  
  monitoring_period    = "60"
  backup_retention_period = 7
  backup_time         = "03:00Z-04:00Z"
  maintenance_window  = "22:00Z-02:00Z"
  
  deletion_protection = false
  ssl_enabled        = 1
  
  tags = var.common_tags
}

resource "alicloud_rds_account" "main" {
  db_instance_id   = alicloud_db_instance.main.id
  account_name     = "postgres"
  account_password = "Terraform123!"
  account_type     = "Super"
}

resource "alicloud_db_database" "main" {
  instance_id = alicloud_db_instance.main.id
  name        = "swen"
  character_set = "UTF8"
  description = "Main application database"
}

# Redis (ApsaraCache)
resource "alicloud_kvstore_instance" "redis" {
  db_instance_name = "${local.name_prefix}-redis"
  instance_class   = var.redis_config.node_type
  instance_type    = "Redis"
  engine_version   = var.redis_config.engine_version
  vswitch_id      = alicloud_vswitch.private[0].id
  security_group_id = alicloud_security_group.redis.id
  
  payment_type     = "PostPaid"
  config = {
    "maxmemory-policy" = "volatile-lru"
  }
  
  backup_policy {
    backup_time   = "03:00Z-04:00Z"
    backup_period = ["Monday", "Wednesday", "Friday"]
  }
  
  tags = var.common_tags
}

# Log Service
resource "alicloud_log_project" "main" {
  name        = "${local.name_prefix}-logs"
  description = "Log project for ${var.project_name}"

  tags = var.common_tags
}

resource "alicloud_log_store" "app" {
  project = alicloud_log_project.main.name
  name    = "application-logs"
  
  retention_period   = 30
  shard_count       = 1
  auto_split        = true
  max_split_shard_count = 60
  append_meta       = true

  tags = var.common_tags
}
