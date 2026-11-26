# Placeholder values only. They are valid so that `terraform plan` succeeds,
# but none of them is real. For your own run, copy this file to a new name
# (any .tfvars file other than this one is ignored by git) and replace the values:
#   cp example.tfvars dev.tfvars

# Region: where every resource is created.
aws_region = "us-east-1"

# Network: the VPC and its four subnets. These match the defaults; change them
# only if they overlap a network you need to connect to.
vpc_cidr              = "10.0.0.0/16"
public_subnet_a_cidr  = "10.0.1.0/24"
public_subnet_b_cidr  = "10.0.2.0/24"
private_subnet_a_cidr = "10.0.11.0/24"
private_subnet_b_cidr = "10.0.12.0/24"

# SSH access: your own public IP with /32 (find it with: curl https://checkip.amazonaws.com).
allowed_ssh_cidr = "203.0.113.10/32" # documentation-only range, not a real IP

# Database credentials: choose your own and never commit them.
db_username = "velaadmin"
db_password = "ChangeMe-Placeholder-123" # placeholder; 8+ characters, no / @ " or spaces

# Static assets bucket: S3 names are global, so pick a unique one.
s3_bucket_name = "vela-assets-example-1234"
