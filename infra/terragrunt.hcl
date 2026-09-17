remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket         = "vlebediev-tf-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "vlebediev-tf-locks"
    encrypt        = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<PROVIDER
provider "aws" {
  region = "eu-central-1"
}
PROVIDER
}

locals {
  env = "dev"
}

terraform {
  before_hook "env_start" {
    commands = ["apply", "plan", "destroy"]
    execute  = ["echo", "[INFO] Terragrunt is running to configure ${upper(local.env)} environment"]
  }

  after_hook "env_done" {
    commands     = ["apply", "plan", "destroy"]
    execute      = ["echo", "[INFO] Terragrunt configured ${upper(local.env)} environment"]
    run_on_error = false
  }
}
