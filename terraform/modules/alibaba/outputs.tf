output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = alicloud_slb_load_balancer.main.address
}

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = alicloud_db_instance.main.connection_string
  sensitive   = true
}

output "database_port" {
  description = "RDS instance port"
  value       = alicloud_db_instance.main.port
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = alicloud_kvstore_instance.redis.connection_domain
}

output "redis_port" {
  description = "Redis cluster port"
  value       = alicloud_kvstore_instance.redis.port
}

output "microservice_urls" {
  description = "URLs for each microservice"
  value = {
    for service, config in var.microservices : service => "http://${alicloud_slb_load_balancer.main.address}${config.path}"
  }
}

output "vpc_id" {
  description = "VPC ID"
  value       = alicloud_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = alicloud_vpc.main.cidr_block
}

output "public_vswitch_ids" {
  description = "Public vSwitch IDs"
  value       = alicloud_vswitch.public[*].id
}

output "private_vswitch_ids" {
  description = "Private vSwitch IDs"
  value       = alicloud_vswitch.private[*].id
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = alicloud_cs_kubernetes_cluster.main.name
}

output "cluster_id" {
  description = "Kubernetes cluster ID"
  value       = alicloud_cs_kubernetes_cluster.main.id
}

output "acr_repository_url" {
  description = "ACR repository URL"
  value       = "${alicloud_cr_repo.app.repo_full_name}:latest"
}

output "security_group_ids" {
  description = "Security group IDs"
  value = {
    slb          = alicloud_security_group.slb.id
    ecs_service  = alicloud_security_group.ecs_service.id
    database     = alicloud_security_group.database.id
    redis        = alicloud_security_group.redis.id
  }
}

output "log_project_name" {
  description = "Log project name"
  value       = alicloud_log_project.main.name
}

output "log_store_name" {
  description = "Log store name"
  value       = alicloud_log_store.app.name
}
