variable "name" {
  type        = string
  description = "Name for the WordPress instance and related resources"
}

variable "ami_id" {
  type        = string
  description = "AMI ID (Amazon Linux)"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "disk_size" {
  type    = number
  default = 10
}

variable "vpc_id" {
  type        = string
  description = "VPC to place the SG in"
}

variable "subnet_id" {
  type        = string
  description = "Public subnet for the instance"
}

variable "key_name" {
  type    = string
  default = null
}

variable "ecr_repository_name" {
  type        = string
  description = "Name of the shared ECR repo holding the WordPress image"
  default     = "vlebediev-wordpress"
}

variable "ssm_prefix" {
  type        = string
  description = "SSM path prefix where DB creds live"
  default     = "/vlebediev/wordpress"
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}
