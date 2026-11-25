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

## Design decisions

## Security notes

## Cost
