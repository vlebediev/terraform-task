include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/modules/rds"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id             = "vpc-mock"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2"]
  }
}

inputs = {
  identifier   = "vlebediev-wordpress"
  db_name      = "wordpress"
  db_username  = "wpadmin"
  subnet_ids   = dependency.vpc.outputs.private_subnet_ids
  vpc_id       = dependency.vpc.outputs.vpc_id
  allowed_cidr = "10.20.0.0/16"
  ssm_prefix   = "/vlebediev/wordpress"
}
