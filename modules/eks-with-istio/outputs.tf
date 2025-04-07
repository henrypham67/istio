output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_owner_id" {
  value = module.vpc.vpc_owner_id
}

output "private_route_table_ids" {
  value = module.vpc.private_route_table_ids
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "cluster_name" {
  value = module.eks.cluster_name
}