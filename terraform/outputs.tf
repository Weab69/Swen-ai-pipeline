output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = var.cloud_provider == "aws" ? (
    length(module.aws_infrastructure) > 0 ? module.aws_infrastructure[0].load_balancer_dns : ""
  ) : (
    length(module.alibaba_infrastructure) > 0 ? module.alibaba_infrastructure[0].load_balancer_dns : ""
  )
}

output "database_endpoint" {
  description = "Database endpoint"
  value       = var.cloud_provider == "aws" ? (
    length(module.aws_infrastructure) > 0 ? module.aws_infrastructure[0].database_endpoint : ""
  ) : (
    length(module.alibaba_infrastructure) > 0 ? module.alibaba_infrastructure[0].database_endpoint : ""
  )
  sensitive = true
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = var.cloud_provider == "aws" ? (
    length(module.aws_infrastructure) > 0 ? module.aws_infrastructure[0].redis_endpoint : ""
  ) : (
    length(module.alibaba_infrastructure) > 0 ? module.alibaba_infrastructure[0].redis_endpoint : ""
  )
}

output "microservice_urls" {
  description = "URLs for each microservice"
  value       = var.cloud_provider == "aws" ? (
    length(module.aws_infrastructure) > 0 ? module.aws_infrastructure[0].microservice_urls : {}
  ) : (
    length(module.alibaba_infrastructure) > 0 ? module.alibaba_infrastructure[0].microservice_urls : {}
  )
}

output "vpc_id" {
  description = "VPC ID"
  value       = var.cloud_provider == "aws" ? (
    length(module.aws_infrastructure) > 0 ? module.aws_infrastructure[0].vpc_id : ""
  ) : (
    length(module.alibaba_infrastructure) > 0 ? module.alibaba_infrastructure[0].vpc_id : ""
  )
}

output "container_cluster_name" {
  description = "Container cluster name"
  value       = var.cloud_provider == "aws" ? (
    length(module.aws_infrastructure) > 0 ? module.aws_infrastructure[0].cluster_name : ""
  ) : (
    length(module.alibaba_infrastructure) > 0 ? module.alibaba_infrastructure[0].cluster_name : ""
  )
}

output "registry_url" {
  description = "Container registry URL"
  value       = var.cloud_provider == "aws" ? (
    length(module.aws_infrastructure) > 0 ? module.aws_infrastructure[0].ecr_repository_url : ""
  ) : (
    length(module.alibaba_infrastructure) > 0 ? module.alibaba_infrastructure[0].acr_repository_url : ""
  )
}

output "security_group_ids" {
  description = "Security group IDs"
  value       = var.cloud_provider == "aws" ? (
    length(module.aws_infrastructure) > 0 ? module.aws_infrastructure[0].security_group_ids : {}
  ) : (
    length(module.alibaba_infrastructure) > 0 ? module.alibaba_infrastructure[0].security_group_ids : {}
  )
}

output "network_info" {
  description = "Network information"
  value = var.cloud_provider == "aws" ? (
    length(module.aws_infrastructure) > 0 ? {
      vpc_id = module.aws_infrastructure[0].vpc_id
      vpc_cidr = module.aws_infrastructure[0].vpc_cidr
      public_subnet_ids = module.aws_infrastructure[0].public_subnet_ids
      private_subnet_ids = module.aws_infrastructure[0].private_subnet_ids
    } : {}
  ) : (
    length(module.alibaba_infrastructure) > 0 ? {
      vpc_id = module.alibaba_infrastructure[0].vpc_id
      vpc_cidr = module.alibaba_infrastructure[0].vpc_cidr
      public_vswitch_ids = module.alibaba_infrastructure[0].public_vswitch_ids
      private_vswitch_ids = module.alibaba_infrastructure[0].private_vswitch_ids
    } : {}
  )
}

output "deployment_info" {
  description = "Deployment information summary"
  value = {
    cloud_provider = var.cloud_provider
    environment = var.environment
    project_name = var.project_name
    region = var.region
    load_balancer_url = var.cloud_provider == "aws" ? (
      length(module.aws_infrastructure) > 0 ? "http://${module.aws_infrastructure[0].load_balancer_dns}" : ""
    ) : (
      length(module.alibaba_infrastructure) > 0 ? "http://${module.alibaba_infrastructure[0].load_balancer_dns}" : ""
    )
  }
}
