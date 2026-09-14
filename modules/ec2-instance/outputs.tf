output "instance_id" {
  value = aws_instance.this.id
}

output "name" {
  value = var.name
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "public_ip" {
  value = aws_instance.this.public_ip
}
