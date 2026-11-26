variable "aws_region" {
  description = "AWS region to deploy all resources into."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_ssh_cidr" {
  description = "Your IP address in CIDR notation allowed to SSH into the EC2 instance (e.g. 203.0.113.5/32)."
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the RDS instance."
  type        = string
  sensitive   = true
}

variable "s3_bucket_name" {
  description = "Globally unique name for the S3 static assets bucket."
  type        = string
}

variable "public_subnet_a_cidr" {
  description = "CIDR block for the first public subnet, inside the VPC CIDR."
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_a_cidr, 0))
    error_message = "public_subnet_a_cidr must be a valid CIDR block, for example 10.0.1.0/24."
  }
}

variable "public_subnet_b_cidr" {
  description = "CIDR block for the second public subnet, inside the VPC CIDR."
  type        = string
  default     = "10.0.2.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_b_cidr, 0))
    error_message = "public_subnet_b_cidr must be a valid CIDR block, for example 10.0.2.0/24."
  }
}

variable "private_subnet_a_cidr" {
  description = "CIDR block for the first private subnet (database), inside the VPC CIDR."
  type        = string
  default     = "10.0.11.0/24"

  validation {
    condition     = can(cidrhost(var.private_subnet_a_cidr, 0))
    error_message = "private_subnet_a_cidr must be a valid CIDR block, for example 10.0.11.0/24."
  }
}

variable "private_subnet_b_cidr" {
  description = "CIDR block for the second private subnet (database), inside the VPC CIDR."
  type        = string
  default     = "10.0.12.0/24"

  validation {
    condition     = can(cidrhost(var.private_subnet_b_cidr, 0))
    error_message = "private_subnet_b_cidr must be a valid CIDR block, for example 10.0.12.0/24."
  }
}
