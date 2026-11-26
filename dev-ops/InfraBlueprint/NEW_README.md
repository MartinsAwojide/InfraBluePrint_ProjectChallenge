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

## Variables

| Name | Type | Default | Description | Sensitive |
| --- | --- | --- | --- | --- |
| `vpc_cidr` | string | `10.0.0.0/16` | CIDR block for the VPC. | No |
| `public_subnet_a_cidr` | string | `10.0.1.0/24` | First public subnet, in the first Availability Zone. | No |
| `public_subnet_b_cidr` | string | `10.0.2.0/24` | Second public subnet, in the second Availability Zone. | No |
| `private_subnet_a_cidr` | string | `10.0.11.0/24` | First private subnet (database), in the first Availability Zone. | No |
| `private_subnet_b_cidr` | string | `10.0.12.0/24` | Second private subnet (database), in the second Availability Zone. | No |
| `s3_bucket_name` | string | none (required) | Globally unique name for the static assets bucket: 3 to 63 lowercase letters, digits or hyphens. | No |

## Design decisions

### No NAT Gateway

The private subnets have no route to the internet: they use the VPC's main route table, which only routes inside the VPC. The database does not need outbound internet access, so there is no NAT Gateway, which also avoids its hourly charge. If a private workload later needs to reach the internet (for patching or external APIs), a NAT Gateway in a public subnet is the addition to make. See [ADR 0005](./docs/adr/0005-network-layout.md).

### Instance profile instead of access keys

The web server gets its AWS permissions from an IAM role attached through an instance profile (`vela-web-role`, `vela-web-profile`), so no access keys are stored on the instance or in the code. The role can only call `s3:GetObject` and `s3:PutObject` on objects in the assets bucket, nothing else. The instance requires IMDSv2, which protects those temporary credentials from server-side request forgery, and its root volume is encrypted. See [ADR 0007](./docs/adr/0007-compute-and-iam.md).

### SSE-S3 encryption instead of KMS

The assets bucket is encrypted at rest with S3-managed keys (SSE-S3). With a KMS key, the EC2 instance's role would also need KMS permissions to read and write objects, which would break the rule that the role may only use `s3:GetObject` and `s3:PutObject`. All public access is blocked, versioning keeps every previous version of an object, and `force_destroy` is off, so `terraform destroy` will not delete a bucket that still holds objects. See [ADR 0009](./docs/adr/0009-storage-encryption.md).

## Security notes

## Cost
