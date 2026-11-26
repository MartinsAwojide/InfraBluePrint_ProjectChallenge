resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Web server: HTTP and HTTPS from anywhere, SSH from the admin IP only"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "web_http" {
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
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.web.name

  # No key pair: SSH uses EC2 Instance Connect, preinstalled on Amazon Linux 2023. IAM authorizes
  # a one-time public key valid for 60 seconds, and web-sg accepts port 22 only from allowed_ssh_cidr.

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
    resources = ["${var.assets_bucket_arn}/*"]
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
