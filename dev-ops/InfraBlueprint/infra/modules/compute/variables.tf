variable "vpc_id" {
  description = "ID of the VPC that web-sg belongs to."
  type        = string
}

variable "subnet_id" {
  description = "ID of the public subnet the web server runs in."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "The only CIDR block allowed to SSH into the web server."
  type        = string
}

variable "assets_bucket_arn" {
  description = "ARN of the static assets bucket the web server may read and write objects in."
  type        = string
}
