variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "vpc_name" {
  type    = string
  default = "vlebediev-vpc"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.10.1.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.10.2.0/24", "10.10.3.0/24"]
}

variable "nat_enabled" {
  type    = bool
  default = false
}
variable "key_public_key" {
  type        = string
  description = "Public SSH key material for the EC2 key pair"
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL8NEg2gaiVJCBWbeLPa0rs4Iv/S+87zkMuhKx4kL+oj vlebediev@HP-ProBook-455-G7"
}

variable "ami_id" {
  type        = string
  description = "AMI ID (latest Amazon Linux) - only hardcoded value in the project"
  default     = "ami-03b2339b9507d3747"
}

