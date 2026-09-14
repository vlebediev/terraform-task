variable "vpc_name" {
  type        = string
  description = "Name tag for the VPC and related resources"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnets" {
  type        = list(string)
  description = "CIDRs for public subnets. Empty list creates none."
  default     = []

  validation {
    condition     = length(var.public_subnets) <= 2
    error_message = "No more than 2 public subnets are allowed."
  }
}

variable "private_subnets" {
  type        = list(string)
  description = "CIDRs for private subnets. Empty list creates none."
  default     = []

  validation {
    condition     = length(var.private_subnets) <= 2
    error_message = "No more than 2 private subnets are allowed."
  }
}

variable "nat_enabled" {
  type        = bool
  description = "Create a single NAT gateway for the private subnets"
  default     = false
}
