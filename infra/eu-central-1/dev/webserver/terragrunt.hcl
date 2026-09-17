include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/modules/ec2-instance"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id            = "vpc-mock"
    public_subnet_ids = ["subnet-mock"]
  }
}

inputs = {
  name                = "vlebediev-tg-webserver"
  ami_id              = "ami-03b2339b9507d3747"
  instance_type       = "t2.micro"
  subnet_id           = dependency.vpc.outputs.public_subnet_ids[0]
  disk_size           = 10
  associate_public_ip = true
}
