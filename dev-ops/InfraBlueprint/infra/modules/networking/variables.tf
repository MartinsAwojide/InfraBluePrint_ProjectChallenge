variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_a_cidr" {
  description = "CIDR block for the first public subnet, in the first Availability Zone."
  type        = string
}

variable "public_subnet_b_cidr" {
  description = "CIDR block for the second public subnet, in the second Availability Zone."
  type        = string
}

variable "private_subnet_a_cidr" {
  description = "CIDR block for the first private subnet (database), in the first Availability Zone."
  type        = string
}

variable "private_subnet_b_cidr" {
  description = "CIDR block for the second private subnet (database), in the second Availability Zone."
  type        = string
}
