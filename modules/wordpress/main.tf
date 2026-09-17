data "aws_caller_identity" "current" {}

# read the shared ECR repo (created in shared/ecr, NOT here)
data "aws_ecr_repository" "wordpress" {
  name = var.ecr_repository_name
}

# --- IAM: instance profile with SSM read + ECR pull ---
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "perms" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_prefix}/*"]
  }
  statement {
    actions   = ["kms:Decrypt"]
    resources = ["*"]
  }
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

resource "aws_iam_role_policy" "this" {
  name   = "${var.name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.perms.json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-profile"
  role = aws_iam_role.this.name
}

# --- SG: SSH + HTTP ---
resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "SSH and HTTP for WordPress"
  vpc_id      = var.vpc_id

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

  tags = { Name = "${var.name}-sg" }
}

# --- The instance ---
resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  user_data_replace_on_change = true

  user_data = <<-SCRIPT
    #!/bin/bash
    set -euxo pipefail
    exec > /var/log/user-data.log 2>&1

    dnf install -y docker
    systemctl enable --now docker

    REGION="${var.aws_region}"
    ECR="${data.aws_ecr_repository.wordpress.repository_url}"
    REGISTRY="$${ECR%%/*}"

    aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
    docker pull "$ECR:latest"
    docker run -d --restart unless-stopped -p 80:80 --name wordpress "$ECR:latest"
  SCRIPT

  root_block_device {
    volume_size = var.disk_size
    volume_type = "gp3"
  }

  tags = { Name = var.name }

  lifecycle {
    create_before_destroy = true
  }
}
