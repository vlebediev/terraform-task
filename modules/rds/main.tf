resource "random_password" "db" {
  length  = 20
  special = false
}

# --- Self-contained SG: MySQL from within the VPC ---
resource "aws_security_group" "rds" {
  name        = "${var.identifier}-rds-sg"
  description = "Allow MySQL from within the VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.identifier}-rds-sg" }
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
  vpc_security_group_ids = [aws_security_group.rds.id]

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
