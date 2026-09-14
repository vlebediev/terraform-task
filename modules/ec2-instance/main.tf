resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = var.associate_public_ip
  key_name                    = var.key_name
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = var.iam_instance_profile
  user_data                   = var.user_data

  root_block_device {
    volume_size = var.disk_size
    volume_type = "gp3"
  }

  tags = { Name = var.name }

  lifecycle {
    create_before_destroy = true
  }
}
