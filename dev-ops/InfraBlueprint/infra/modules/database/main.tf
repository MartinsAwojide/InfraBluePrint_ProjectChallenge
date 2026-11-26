terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "Database: PostgreSQL from web-sg only"
  vpc_id      = var.vpc_id
}

# Referencing web-sg instead of an IP range keeps working when the instance's IP changes.
resource "aws_vpc_security_group_ingress_rule" "db_postgres_from_web" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from web-sg only"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = var.web_sg_id
}

# RDS needs a subnet group covering at least two Availability Zones, even for a single-AZ database.
resource "aws_db_subnet_group" "main" {
  name       = "vela-db-subnets"
  subnet_ids = var.subnet_ids
}

resource "aws_db_instance" "main" {
  identifier        = "vela-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_encrypted = true

  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  # Lets `terraform destroy` remove the database when done; this also deletes its data.
  skip_final_snapshot = true
  deletion_protection = false
}
