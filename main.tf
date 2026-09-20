terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "vlebediev-tf-state"
    key            = "terraform-task/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "vlebediev-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"

  vpc_name        = var.vpc_name
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  nat_enabled     = var.nat_enabled
}

# --- Key pair (shared by public WordPress + private instances) ---
resource "aws_key_pair" "this" {
  key_name   = "vlebediev-key"
  public_key = var.key_public_key
}

# --- WordPress (public): instance + IAM + SG + user-data + EIP + DNS, image from shared ECR ---
module "wordpress" {
  source = "./modules/wordpress"

  name        = "vlebediev-wordpress"
  ami_id      = var.ami_id
  vpc_id      = module.vpc.vpc_id
  subnet_id   = module.vpc.public_subnet_ids[0]
  key_name    = aws_key_pair.this.key_name
  aws_region  = var.aws_region
  domain_name = "vlebediev.romexsoft.net"
  zone_name   = "vlebediev.romexsoft.net"
}

# --- Private instances: 2x t2.nano, 8GB, private only ---
module "ec2_private" {
  source = "./modules/ec2-instance"
  count  = 2

  name                = "vlebediev-private-${count.index + 1}"
  ami_id              = var.ami_id
  instance_type       = "t2.nano"
  subnet_id           = module.vpc.private_subnet_ids[0]
  disk_size           = 8
  associate_public_ip = false
  key_name            = aws_key_pair.this.key_name
}

# --- SSM /Instances parameter with JSON content ---
resource "aws_ssm_parameter" "instances" {
  name = "/Instances"
  type = "String"

  value = jsonencode({
    public = {
      name      = "vlebediev-wordpress"
      public-ip = module.wordpress.public_ip
    }
    private = [
      for inst in module.ec2_private : {
        name = inst.name
      }
    ]
  })
}

module "rds" {
  source = "./modules/rds"

  identifier   = "vlebediev-wordpress"
  db_name      = "wordpress"
  db_username  = "wpadmin"
  subnet_ids   = module.vpc.private_subnet_ids
  vpc_id       = module.vpc.vpc_id
  allowed_cidr = var.vpc_cidr
  ssm_prefix   = "/vlebediev/wordpress"
}
