# Vela Payments infrastructure

Terraform code that rebuilds Vela Payments' AWS infrastructure from scratch: a custom VPC, an EC2 web server, a private RDS PostgreSQL database and a private S3 bucket for static assets.

## Quick start

## Architecture

The full diagram notes are in [docs/architecture.md](./docs/architecture.md).

```mermaid
flowchart TB
    internet(["Internet"])
    admin(["Admin IP<br/>var.allowed_ssh_cidr"])

    subgraph aws["AWS region (var.aws_region)"]
        direction TB

        subgraph vpc["VPC 10.0.0.0/16 (custom, not the default VPC)"]
            direction TB
            igw["Internet Gateway"]
            rtpub["Public route table<br/>0.0.0.0/0 → Internet Gateway"]
            rtmain["Main route table<br/>local routes only"]

            subgraph az1["Availability Zone 1"]
                direction TB
                subgraph pub1["Public subnet 10.0.1.0/24"]
                    ec2["EC2 t2.micro, Amazon Linux 2023<br/>security group: web-sg"]
                end
                priv1["Private subnet<br/>10.0.11.0/24"]
            end

            subgraph az2["Availability Zone 2"]
                direction TB
                pub2["Public subnet 10.0.2.0/24<br/>reserved for a load balancer or scaling"]
                priv2["Private subnet<br/>10.0.12.0/24"]
            end

            rds[("RDS PostgreSQL 15, db.t3.micro<br/>security group: db-sg<br/>not publicly accessible<br/>runs in one private subnet, chosen by AWS")]
        end

        s3[("S3 bucket: static assets<br/>public access blocked, versioned")]
        iam["IAM role and instance profile<br/>s3:GetObject, s3:PutObject<br/>on this bucket only"]
    end

    state[("Terraform state bucket<br/>created manually, outside this stack")]

    internet -- "HTTP 80, HTTPS 443" --> igw
    admin -- "SSH 22" --> igw
    igw -- "allowed by web-sg" --> ec2
    rtpub -. "associated" .- pub1
    rtpub -. "associated" .- pub2
    rtmain -. "associated" .- priv1
    rtmain -. "associated" .- priv2
    rds -. "DB subnet group" .- priv1
    rds -. "DB subnet group" .- priv2
    ec2 -- "PostgreSQL 5432<br/>db-sg allows web-sg only" --> rds
    iam -. "attached to" .- ec2
    ec2 -- "objects, through the Internet Gateway" --> s3
```

## Setup

### 1. Prerequisites

- Terraform 1.5.7 or later, below 2.0 (`terraform version`)
- AWS CLI v2, to create the state bucket
- An AWS account and an IAM user or role you can use from the command line

### 2. Configure AWS credentials

Terraform reads credentials from the standard AWS locations, never from the code. Use one of:

```sh
aws configure                     # writes ~/.aws/credentials
export AWS_PROFILE=your-profile   # or pick a named profile
```

Check that they work with `aws sts get-caller-identity`.

**Permissions.** `terraform init` and `terraform plan` only read: they need EC2 describe access (Availability Zones, the AMI lookup) and read and write access to your own state bucket. A real `terraform apply` also creates EC2, RDS, S3 and IAM resources, so it needs permission to manage all four, including IAM roles and instance profiles (in a sandbox account, `AdministratorAccess` is the simplest choice). Without the IAM permissions, `apply` stops partway with an `iam:CreateRole` access denied error.

### 3. Create the state bucket (once, by hand)

Terraform stores its state in an S3 bucket, which must exist before `terraform init`. It is created outside this code on purpose, so destroying the stack never deletes its own state. Pick a globally unique name and run:

```sh
BUCKET=your-terraform-state-bucket

aws s3api create-bucket --bucket "$BUCKET" --region us-east-1
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

Versioning keeps every earlier copy of the state, and the state holds the database password, so the bucket stays private and encrypted. For a region other than `us-east-1`, add `--create-bucket-configuration LocationConstraint=<region>` to `create-bucket`, and set `region` in `backend.hcl` (next step).

### 4. Point Terraform at your bucket

```sh
cd infra
cp backend.hcl.example backend.hcl
```

Edit `backend.hcl` and set `bucket` to the name from step 3. The file is ignored by git, so your bucket name stays out of the repository.

### 5. Choose your variable values

`example.tfvars` (in the project folder, next to `infra/`) holds valid placeholder values, enough to run `plan`. To build real infrastructure, copy it and put in your own IP address, database credentials and a unique bucket name:

```sh
cp ../example.tfvars ../dev.tfvars
```

Every `.tfvars` file except `example.tfvars` is ignored by git.

### 6. Initialise and plan

From `infra/`:

```sh
terraform init -backend-config=backend.hcl
terraform plan -var-file=../example.tfvars
```

`plan` shows 26 resources to create and changes nothing. To build them, run `terraform apply -var-file=../dev.tfvars`; this is billed (see Cost). When done, remove everything with `terraform destroy -var-file=../dev.tfvars`.

## Variables

| Name | Type | Default | Description | Sensitive |
| --- | --- | --- | --- | --- |
| `aws_region` | string | none (required) | AWS region to deploy all resources into. | No |
| `vpc_cidr` | string | `10.0.0.0/16` | CIDR block for the VPC. | No |
| `public_subnet_a_cidr` | string | `10.0.1.0/24` | First public subnet, in the first Availability Zone. | No |
| `public_subnet_b_cidr` | string | `10.0.2.0/24` | Second public subnet, in the second Availability Zone. | No |
| `private_subnet_a_cidr` | string | `10.0.11.0/24` | First private subnet (database), in the first Availability Zone. | No |
| `private_subnet_b_cidr` | string | `10.0.12.0/24` | Second private subnet (database), in the second Availability Zone. | No |
| `allowed_ssh_cidr` | string | none (required) | Your IP address in CIDR notation (for example `203.0.113.5/32`), the only source allowed to SSH into the web server. `0.0.0.0/0` is rejected. | No |
| `db_username` | string | none (required) | Master username for the PostgreSQL database. | Yes |
| `db_password` | string | none (required) | Master password for the PostgreSQL database. | Yes |
| `s3_bucket_name` | string | none (required) | Globally unique name for the static assets bucket: 3 to 63 lowercase letters, digits or hyphens. | No |

## Design decisions

### No NAT Gateway

The private subnets have no route to the internet: they use the VPC's main route table, which only routes inside the VPC. The database does not need outbound internet access, so there is no NAT Gateway, which also avoids its hourly charge. If a private workload later needs to reach the internet (for patching or external APIs), a NAT Gateway in a public subnet is the addition to make. See [ADR 0005](./docs/adr/0005-network-layout.md).

### Database in private subnets

The PostgreSQL 15 database (`db.t3.micro`) runs in the two private subnets, which have no route to the internet, and `publicly_accessible` is set to `false`. Its security group, `db-sg`, accepts port 5432 only from the web server's security group, `web-sg`, by reference rather than by IP address, so only the web server can connect. Storage is encrypted at rest. See [ADR 0008](./docs/adr/0008-database.md).

### Instance profile instead of access keys

The web server gets its AWS permissions from an IAM role attached through an instance profile (`vela-web-role`, `vela-web-profile`), so no access keys are stored on the instance or in the code. The role can only call `s3:GetObject` and `s3:PutObject` on objects in the assets bucket, nothing else. The instance requires IMDSv2, which protects those temporary credentials from server-side request forgery, and its root volume is encrypted. See [ADR 0007](./docs/adr/0007-compute-and-iam.md).

### SSE-S3 encryption instead of KMS

The assets bucket is encrypted at rest with S3-managed keys (SSE-S3). With a KMS key, the EC2 instance's role would also need KMS permissions to read and write objects, which would break the rule that the role may only use `s3:GetObject` and `s3:PutObject`. All public access is blocked, versioning keeps every previous version of an object, and `force_destroy` is off, so `terraform destroy` will not delete a bucket that still holds objects. See [ADR 0009](./docs/adr/0009-storage-encryption.md).

### Partial backend configuration

State lives in S3, but the bucket name is not in the code. `main.tf` sets the state key, region and encryption, and the bucket name comes from `backend.hcl` at `terraform init -backend-config=backend.hcl`. Terraform reads the backend before any variables exist, so a backend block cannot use `var.` values; a partial configuration is the documented way to keep account-specific settings out of the code. Each engineer points the same code at their own bucket without editing it. There is no state locking, which is fine for one engineer; DynamoDB locking is the next step for a team. See [ADR 0004](./docs/adr/0004-remote-state-partial-backend.md).

## Security notes

- **The database password is stored in Terraform state.** `db_password` is marked sensitive, so Terraform hides it in plan and apply output, but it is still written to the state file in plain text. The state bucket must therefore stay private, encrypted and versioned. For production, `manage_master_user_password = true` lets RDS generate the password and keep it in AWS Secrets Manager, so it never reaches state.
- **Real values never go into `example.tfvars`.** Put your own IP address, database credentials and bucket name in a separate `.tfvars` file; `*.tfvars` files other than `example.tfvars` are ignored by git.

## Cost
