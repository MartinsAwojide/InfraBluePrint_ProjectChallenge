# 0008. Single-AZ private RDS with credentials from variables

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

The brief requires PostgreSQL 15 on `db.t3.micro` in the private subnets, not publicly accessible, with the username and password passed in as Terraform variables that have no default values.

## Decision

A single-AZ `aws_db_instance` in a subnet group spanning both private subnets, with `publicly_accessible = false`, `storage_encrypted = true` and 20 GB of storage. Credentials come from sensitive variables. For easy teardown, `skip_final_snapshot = true` and `deletion_protection = false`.

## Consequences

The database is reachable only from `web-sg` inside the VPC, and stays within free-tier limits where they apply. Single-AZ means downtime during an AZ outage or maintenance. Terraform stores the master password in state in plain text, so the state bucket must be private, encrypted and versioned (ADR 0004). Teardown skips the final snapshot, so `destroy` deletes the data.

## Alternatives to explore

- **`manage_master_user_password = true`:** RDS generates the password and keeps it in Secrets Manager, so it never appears in state. The production choice, but it replaces the variable approach the brief asks for.
- **Final snapshot on destroy:** `skip_final_snapshot = false` with a `final_snapshot_identifier`. This is the brief's snapshot bonus; the snapshot outlives the stack and costs storage.
- **Multi-AZ:** automatic failover to a standby in the second private subnet. Roughly doubles the database cost.
- **Deletion protection on:** guards against accidental destroys, at the cost of an extra step when tearing down.
- **IAM database authentication:** short-lived tokens instead of a static password.
