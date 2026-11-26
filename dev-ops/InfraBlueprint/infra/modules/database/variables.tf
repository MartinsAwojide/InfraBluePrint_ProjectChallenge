variable "vpc_id" {
  description = "ID of the VPC that db-sg belongs to."
  type        = string
}

variable "subnet_ids" {
  description = "IDs of the private subnets for the database subnet group (at least two Availability Zones)."
  type        = list(string)
}

variable "web_sg_id" {
  description = "ID of web-sg, the only security group allowed to reach PostgreSQL."
  type        = string
}

variable "db_username" {
  description = "Master username for the PostgreSQL database."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the PostgreSQL database."
  type        = string
  sensitive   = true
}
