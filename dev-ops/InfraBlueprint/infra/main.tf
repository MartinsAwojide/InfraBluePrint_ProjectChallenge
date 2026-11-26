terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Partial configuration: the state bucket name comes from backend.hcl at init
  # (terraform init -backend-config=backend.hcl), so each engineer uses their own
  # bucket without editing code. Backend blocks cannot read variables, so the
  # region is written out here.
  backend "s3" {
    key     = "vela-payments/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
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

# Each layer is a module under modules/; the root wires their outputs together.

module "networking" {
  source = "./modules/networking"

  vpc_cidr              = var.vpc_cidr
  public_subnet_a_cidr  = var.public_subnet_a_cidr
  public_subnet_b_cidr  = var.public_subnet_b_cidr
  private_subnet_a_cidr = var.private_subnet_a_cidr
  private_subnet_b_cidr = var.private_subnet_b_cidr
}

module "storage" {
  source = "./modules/storage"

  s3_bucket_name = var.s3_bucket_name
}

module "compute" {
  source = "./modules/compute"

  vpc_id            = module.networking.vpc_id
  subnet_id         = module.networking.public_subnet_a_id
  allowed_ssh_cidr  = var.allowed_ssh_cidr
  assets_bucket_arn = module.storage.bucket_arn
}

module "database" {
  source = "./modules/database"

  vpc_id      = module.networking.vpc_id
  subnet_ids  = module.networking.private_subnet_ids
  web_sg_id   = module.compute.web_sg_id
  db_username = var.db_username
  db_password = var.db_password
}
