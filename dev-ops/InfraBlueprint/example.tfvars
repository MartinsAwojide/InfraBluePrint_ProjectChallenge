# Placeholder values only. They are valid so that `terraform plan` succeeds,
# but none of them is real: replace them in your own gitignored .tfvars file.
aws_region       = "us-east-1"
vpc_cidr         = "10.0.0.0/16"
allowed_ssh_cidr = "203.0.113.10/32"          # documentation-only range, not a real IP
db_username      = "velaadmin"
db_password      = "ChangeMe-Placeholder-123" # placeholder, never a real password
s3_bucket_name   = "vela-assets-example-1234"
