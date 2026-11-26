# 0008. Single-AZ private RDS with credentials from variables

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

The brief requires PostgreSQL 15 on `db.t3.micro` in the private subnets, not publicly accessible, with the username and password passed in as Terraform variables that have no default values.

## Decision

A single-AZ `aws_db_instance` in a subnet group spanning both private subnets, with `publicly_accessible = false`, `storage_encrypted = true` and 20 GB of storage. Credentials come from sensitive variables. For easy teardown, `skip_final_snapshot = true` and `deletion_protection = false`.

## Consequences

The database is reachable only from `web-sg` inside the VPC, and stays within free-tier limits where they apply. Single-AZ means downtime during an AZ outage or maintenance. Terraform stores the master password in state in plain text, so the state bucket must be private, encrypted and versioned (ADR 0004). Teardown skips the final snapshot, so `destroy` deletes the data. Minor version upgrades are applied automatically, and tags are copied to any snapshot.

## Security scanner findings accepted

Checkov flags seven more settings on the database. Each is suppressed inline in `main.tf`, because it adds cost or resources the brief does not ask for, or contradicts the decision above:

- **CKV_AWS_293, deletion protection off:** deliberate, so `terraform destroy` works as the brief's cost note asks.
- **CKV_AWS_157, single-AZ:** Multi-AZ roughly doubles the cost (listed below as an alternative).
- **CKV_AWS_161, no IAM database authentication:** the brief requires a username and password from variables (listed below as an alternative).
- **CKV_AWS_129, no log exports:** CloudWatch Logs storage is billed.
- **CKV2_AWS_30, no query logging:** needs a custom parameter group.
- **CKV_AWS_118, no enhanced monitoring:** needs a monitoring IAM role and is billed.
- **CKV_AWS_353, no Performance Insights:** an extra paid feature.

## Alternatives to explore

- **`manage_master_user_password = true`:** RDS generates the password and keeps it in Secrets Manager, so it never appears in state. The production choice, but it replaces the variable approach the brief asks for.
- **Final snapshot on destroy:** `skip_final_snapshot = false` with a `final_snapshot_identifier`. This is the brief's snapshot bonus; the snapshot outlives the stack and costs storage.
- **Multi-AZ:** automatic failover to a standby in the second private subnet. Roughly doubles the database cost.
- **Deletion protection on:** guards against accidental destroys, at the cost of an extra step when tearing down.
- **IAM database authentication:** short-lived tokens instead of a static password.
