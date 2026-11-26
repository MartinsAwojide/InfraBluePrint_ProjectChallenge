# 0005. Two-AZ VPC with private database subnets and no NAT Gateway

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

The brief requires a custom `10.0.0.0/16` VPC with two public and two private subnets in different Availability Zones, an Internet Gateway, and a public route table. The database must not be reachable from the internet.

## Decision

- Public subnets `10.0.1.0/24` and `10.0.2.0/24`, private subnets `10.0.11.0/24` and `10.0.12.0/24`, across the first two available AZs (looked up, never hardcoded). All four are variables.
- One public route table sending `0.0.0.0/0` to the Internet Gateway, associated with the public subnets only.
- Private subnets keep the VPC's main route table, which routes only within the VPC.
- No NAT Gateway.

## Consequences

The database has no route to or from the internet. Two private AZs satisfy RDS's subnet group requirement and leave room for Multi-AZ later. Without a NAT Gateway, nothing in the private subnets can reach the internet (RDS doesn't need to), which saves the hourly NAT cost. The EC2 instance reaches S3 over its public endpoint through the Internet Gateway.

## Security scanner findings accepted

Checkov flags four things in this layout. Each is suppressed inline in `main.tf` with its reason, because fixing it would add resources or cost the brief does not ask for, or would contradict the design:

- **CKV_AWS_130, public subnets assign public IPs:** intended; the web server must be reachable on its public IP.
- **CKV_AWS_394, Availability Zone identity not pinned:** pinning means hardcoding zone IDs. Zone names sort alphabetically, so the first two stay the same when AWS adds a zone.
- **CKV2_AWS_11, no VPC flow logs:** needs a log destination, an IAM role and storage cost (listed below as an alternative).
- **CKV2_AWS_12, default security group not restricted:** restricting it needs an extra `aws_default_security_group` resource. Nothing is attached to the default group; the web server and database use their own.

## Alternatives to explore

- **S3 Gateway VPC endpoint:** free, keeps EC2-to-S3 traffic on the AWS network, and lets the bucket policy require the endpoint. A strong, low-cost hardening step.
- **NAT Gateway:** needed only if private workloads must reach the internet (patching, external APIs). Billed hourly plus data processing.
- **Dedicated private route table:** makes the intent explicit in code rather than relying on the main route table.
- **Network ACLs:** a stateless second layer below security groups. Useful for compliance, but more rules to maintain.
- **VPC Flow Logs:** network audit trail, at a small storage cost.
