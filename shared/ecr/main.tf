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
    key            = "shared/ecr/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "vlebediev-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# --- ECR repo (shared, long-lived, survives stack destroys) ---
resource "aws_ecr_repository" "wordpress" {
  name                 = "vlebediev-wordpress"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # NO force_delete: this is a shared long-lived resource, we don't want
  # a stray destroy wiping the image. Deletion is deliberate only.

  tags = { Name = "vlebediev-wordpress" }
}

# --- Auto build+push the image; re-runs only when Dockerfile/entrypoint change ---
resource "null_resource" "image_push" {
  triggers = {
    dockerfile  = filesha256("${path.module}/../../wordpress-image/Dockerfile")
    entrypoint  = filesha256("${path.module}/../../wordpress-image/entrypoint.sh")
    repo_url    = aws_ecr_repository.wordpress.repository_url
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-CMD
      set -euo pipefail
      ACCOUNT="${data.aws_caller_identity.current.account_id}"
      REGION="${var.aws_region}"
      ECR="${aws_ecr_repository.wordpress.repository_url}"
      REGISTRY="$${ECR%%/*}"

      aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
      docker build -t "$ECR:latest" "${path.module}/../../wordpress-image"
      docker push "$ECR:latest"
    CMD
  }
}
