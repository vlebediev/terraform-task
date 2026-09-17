variable "name" {
  type        = string
  description = "Name tag for the instance"
}

variable "ami_id" {
  type        = string
  description = "AMI ID to launch"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "subnet_id" {
  type        = string
  description = "Subnet to launch the instance in"
}

variable "disk_size" {
  type        = number
  description = "Root volume size in GB"
}

variable "associate_public_ip" {
  type        = bool
  description = "Assign a public IP to the instance"
  default     = false
}

variable "key_name" {
  type        = string
  description = "Name of the EC2 key pair"
  default     = null
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups to attach"
  default     = []
}

variable "iam_instance_profile" {
  type        = string
  description = "IAM instance profile name (for SSM access)"
  default     = null
}

variable "user_data" {
  type        = string
  description = "user-data script"
  default     = null
}
