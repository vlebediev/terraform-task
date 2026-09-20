variable "identifier" {
  type        = string
  description = "RDS instance identifier"
}

variable "db_name" {
  type        = string
  description = "Initial database name"
}

variable "db_username" {
  type        = string
  description = "Master username"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Storage in GB"
  default     = 20
}

variable "engine_version" {
  type        = string
  description = "MySQL engine version"
  default     = "8.0"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the DB subnet group (need >=2 AZs)"
}

variable "vpc_id" {
  type        = string
  description = "VPC for the RDS security group"
}

variable "allowed_cidr" {
  type        = string
  description = "CIDR allowed to reach MySQL (e.g. the VPC CIDR)"
}

variable "ssm_prefix" {
  type        = string
  description = "SSM path prefix to store connection params"
}
