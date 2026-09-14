resource "random_password" "db" {
  length  = 20
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = { Name = "${var.identifier}-subnet-group" }
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids

  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = true

  tags = { Name = var.identifier }
}

# --- Connection params into SSM (paths match the WordPress entrypoint) ---
resource "aws_ssm_parameter" "db_host" {
  name  = "${var.ssm_prefix}/db_host"
  type  = "String"
  value = aws_db_instance.this.address
}

resource "aws_ssm_parameter" "db_name" {
  name  = "${var.ssm_prefix}/db_name"
  type  = "String"
  value = var.db_name
}

resource "aws_ssm_parameter" "db_user" {
  name  = "${var.ssm_prefix}/db_user"
  type  = "String"
  value = var.db_username
}

resource "aws_ssm_parameter" "db_password" {
  name  = "${var.ssm_prefix}/db_password"
  type  = "SecureString"
  value = random_password.db.result
}
