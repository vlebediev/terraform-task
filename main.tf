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

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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

  name                 = "vlebediev-public"
  ami_id               = var.ami_id
  instance_type        = "t2.micro"
  subnet_id            = module.vpc.public_subnet_ids[0]
  disk_size            = 10
  associate_public_ip  = true
  key_name             = aws_key_pair.this.key_name
  security_group_ids   = [aws_security_group.public_ssh.id]
  iam_instance_profile = aws_iam_instance_profile.wordpress.name
  user_data            = local.wordpress_user_data
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

# --- SG for RDS: MySQL only from the public (WordPress) instance ---
resource "aws_security_group" "rds" {
  name        = "vlebediev-rds"
  description = "Allow MySQL from the WordPress instance only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "MySQL from public instance SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.public_ssh.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "vlebediev-rds" }
}

module "rds" {
  source = "./modules/rds"

  identifier             = "vlebediev-wordpress"
  db_name                = "wordpress"
  db_username            = "wpadmin"
  subnet_ids             = module.vpc.private_subnet_ids
  vpc_security_group_ids = [aws_security_group.rds.id]
  ssm_prefix             = "/vlebediev/wordpress"
}

# ============ WordPress: ECR + IAM + user-data ============

data "aws_caller_identity" "current" {}

# --- ECR repo for the WordPress image ---
resource "aws_ecr_repository" "wordpress" {
  name                 = "vlebediev-wordpress"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "vlebediev-wordpress" }
}

# --- IAM role + instance profile for the public (WordPress) instance ---
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "wordpress" {
  name               = "vlebediev-wordpress-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "wordpress" {
  # read WordPress DB params from SSM
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/vlebediev/wordpress/*"]
  }
  # decrypt the SecureString password (default SSM KMS key)
  statement {
    actions   = ["kms:Decrypt"]
    resources = ["*"]
  }
  # pull image from ECR
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "wordpress" {
  name   = "vlebediev-wordpress-policy"
  role   = aws_iam_role.wordpress.id
  policy = data.aws_iam_policy_document.wordpress.json
}

resource "aws_iam_instance_profile" "wordpress" {
  name = "vlebediev-wordpress-profile"
  role = aws_iam_role.wordpress.name
}

locals {
  ecr_url = aws_ecr_repository.wordpress.repository_url

  wordpress_user_data = <<-SCRIPT
    #!/bin/bash
    set -euxo pipefail
    exec > /var/log/user-data.log 2>&1

    dnf install -y docker
    systemctl enable --now docker

    REGION="${var.aws_region}"
    ECR="${aws_ecr_repository.wordpress.repository_url}"
    REGISTRY="$${ECR%%/*}"

    aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
    docker pull "$ECR:latest"
    docker run -d --restart unless-stopped -p 80:80 --name wordpress "$ECR:latest"
  SCRIPT
}
