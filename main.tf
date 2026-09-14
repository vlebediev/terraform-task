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
# --- Key pair ---
resource "aws_key_pair" "this" {
  key_name   = "vlebediev-key"
  public_key = var.key_public_key
}

# --- SG for public instance: SSH from anywhere ---
resource "aws_security_group" "public_ssh" {
  name        = "vlebediev-public-ssh"
  description = "Allow SSH from anywhere"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "vlebediev-public-ssh" }
}

# --- Public instance: t2.micro, 10GB, public IP ---
module "ec2_public" {
  source = "./modules/ec2-instance"

  name                = "vlebediev-public"
  ami_id              = var.ami_id
  instance_type       = "t2.micro"
  subnet_id           = module.vpc.public_subnet_ids[0]
  disk_size           = 10
  associate_public_ip = true
  key_name            = aws_key_pair.this.key_name
  security_group_ids  = [aws_security_group.public_ssh.id]
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

# --- Conditional EIP for the public instance ---
resource "aws_eip" "public" {
  count    = var.enable_eip ? 1 : 0
  instance = module.ec2_public.instance_id
  domain   = "vpc"
  tags     = { Name = "vlebediev-public-eip" }
}

# --- SSM /Instances parameter with JSON content ---
resource "aws_ssm_parameter" "instances" {
  name = "/Instances"
  type = "String"

  value = jsonencode({
    public = {
      name      = module.ec2_public.name
      public-ip = var.enable_eip ? aws_eip.public[0].public_ip : module.ec2_public.public_ip
    }
    private = [
      for inst in module.ec2_private : {
        name = inst.name
      }
    ]
  })
}
