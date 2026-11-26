terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure once your S3 backend bucket exists.
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "vela-payments/terraform.tfstate"
  #   region = var.aws_region
  # }
}

provider "aws" {
  region = var.aws_region

  # Tags every taggable resource, so no resource repeats the tag.
  default_tags {
    tags = {
      Project = "vela-payments"
    }
  }
}

# Networking

# Availability Zones are looked up, never hardcoded, so the code works in any region.
data "aws_availability_zones" "available" {
  #checkov:skip=CKV_AWS_394:Zone IDs would be hardcoded; names sort alphabetically, so names[0] and names[1] stay stable when AWS adds a zone
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "aws_vpc" "main" {
  #checkov:skip=CKV2_AWS_11:Flow logs need extra resources and storage cost the brief does not ask for (see ADR 0005)
  #checkov:skip=CKV2_AWS_12:No resource uses the default security group; the web server and database get their own groups
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_a" {
  #checkov:skip=CKV_AWS_130:Public subnet by design; the web server needs a public IP
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_b" {
  #checkov:skip=CKV_AWS_130:Public subnet by design; the web server needs a public IP
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# The private subnets have no association: they use the VPC's main route table,
# which only routes inside the VPC, so the database has no path to the internet.

# Security groups

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Web server: HTTP and HTTPS from anywhere, SSH from the admin IP only"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "web_http" {
  #checkov:skip=CKV_AWS_260:The brief requires HTTP on port 80 from anywhere for the public web server
  security_group_id = aws_security_group.web.id
  description       = "HTTP from anywhere"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "web_https" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS from anywhere"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "web_ssh" {
  security_group_id = aws_security_group.web.id
  description       = "SSH from the admin IP only"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.allowed_ssh_cidr
}

# Terraform removes the default allow-all outbound rule, so it is declared here.
resource "aws_vpc_security_group_egress_rule" "web_all_outbound" {
  security_group_id = aws_security_group.web.id
  description       = "All outbound traffic (S3, package updates)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "Database: PostgreSQL from web-sg only"
  vpc_id      = aws_vpc.main.id
}

# Referencing web-sg instead of an IP range keeps working when the instance's IP changes.
resource "aws_vpc_security_group_ingress_rule" "db_postgres_from_web" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from web-sg only"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.web.id
}

# Storage

resource "aws_s3_bucket" "assets" {
  #checkov:skip=CKV_AWS_144:Cross-region replication needs a second bucket and IAM role the brief does not ask for (see ADR 0009)
  #checkov:skip=CKV_AWS_145:SSE-S3 instead of KMS, so the EC2 role needs only GetObject and PutObject (see ADR 0009)
  #checkov:skip=CKV_AWS_18:Access logging needs a separate log bucket the brief does not ask for (see ADR 0009)
  #checkov:skip=CKV2_AWS_61:No lifecycle rules; old versions are kept on purpose for a payments client (see ADR 0009)
  #checkov:skip=CKV2_AWS_62:No event notifications; nothing consumes bucket events (see ADR 0009)
  bucket = var.s3_bucket_name
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 encrypts at rest without giving the EC2 role any KMS permissions.
resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Compute

# The newest Amazon Linux 2023 image; x86_64 because t2.micro cannot run ARM images.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "web" {
  #checkov:skip=CKV_AWS_126:Detailed monitoring is billed per instance and the brief does not ask for it (see ADR 0007)
  #checkov:skip=CKV_AWS_135:t2.micro does not support EBS optimization, and the brief requires t2.micro (see ADR 0007)
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.web.name

  # IMDSv2 only: credentials need a session token, which blocks SSRF-style credential theft.
  metadata_options {
    http_tokens = "required"
  }

  # Encrypt the root volume at rest. The provider's default tags don't reach it, so the tag is set here.
  root_block_device {
    encrypted = true
    tags = {
      Project = "vela-payments"
    }
  }
}

# Only EC2 may assume the role.
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "vela-web-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# GetObject and PutObject act on objects, so the resource is the bucket ARN plus /*.
data "aws_iam_policy_document" "web_s3" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.assets.arn}/*"]
  }
}

resource "aws_iam_role_policy" "web_s3" {
  name   = "vela-web-s3-access"
  role   = aws_iam_role.web.id
  policy = data.aws_iam_policy_document.web_s3.json
}

resource "aws_iam_instance_profile" "web" {
  name = "vela-web-profile"
  role = aws_iam_role.web.name
}
