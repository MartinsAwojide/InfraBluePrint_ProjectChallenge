# 0006. Standalone security group rules with an SG reference for the database

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

`web-sg` must allow HTTP and HTTPS from anywhere, SSH from the author's IP only, and all outbound traffic. `db-sg` must allow PostgreSQL only from `web-sg`. Terraform removes AWS's default allow-all egress rule from any security group it manages.

## Decision

Define the two groups with `aws_security_group`, and each rule as a separate `aws_vpc_security_group_ingress_rule` or `aws_vpc_security_group_egress_rule` resource. `db-sg` allows 5432 from `referenced_security_group_id = web-sg`. The SSH source is `var.allowed_ssh_cidr`, validated as a CIDR and rejected if `0.0.0.0/0`. `web-sg` egress is declared explicitly.

## Consequences

One resource per rule gives clean plans and diffs, and each rule carries its own description. The `Project` tag reaches every group and rule through the provider's default tags. Referencing `web-sg` rather than an IP range means any instance in that group can reach the database, and nothing else can, even if addresses change.

## Security scanner findings accepted

- **CKV_AWS_260, port 80 open to `0.0.0.0/0`:** required by the brief for the public web server. Suppressed inline in `main.tf` with this reason. Serving HTTPS only, with port 80 redirecting, would be the hardening step once a certificate exists.

## Alternatives to explore

- **Inline `ingress` and `egress` blocks:** fewer resources, but any rule change rewrites the whole group, and mixing styles causes conflicts.
- **AWS Systems Manager Session Manager instead of SSH:** port 22 closes entirely, and access is controlled by IAM and logged. The strongest security improvement available here.
- **Restricted egress** (only 443 and 5432): least privilege outbound, but blocks package updates unless they are listed.
- **Load balancer in front of EC2:** HTTP and HTTPS then come only from the load balancer's group. Adds hourly cost.
