output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_instance_ip" {
  value = module.wordpress.public_ip
}

output "wordpress_domain" {
  value = module.wordpress.domain
}

output "rds_endpoint" {
  value = module.rds.endpoint
}
