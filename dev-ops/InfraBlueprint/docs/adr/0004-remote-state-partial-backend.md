# 0004. Store state in S3 with a partial backend configuration

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

The brief requires a Terraform S3 backend, with the state bucket created manually before `terraform init`. Reviewers cannot access the author's bucket, and Terraform does not allow variables inside a backend block.

## Decision

Declare `backend "s3"` with literal `key`, `region` and `encrypt = true`, and supply the bucket name at init time from a gitignored `backend.hcl` (template: `backend.hcl.example`). The state bucket is created by hand with versioning on and public access blocked.

## Consequences

Each reviewer points the backend at their own bucket without editing code. The state bucket sits outside Terraform, so deleting the project never deletes its own state. There is no state locking, which is acceptable for a single engineer but not for a team.

## Questions this decision raises

- **Why not use a variable for the bucket?** The backend is configured before variables are evaluated. Writing `region = var.aws_region` or `bucket = var.x` in the block fails `init` with "Variables may not be used here."
- **Why is the region written out but the bucket not?** The region is the same for every reviewer who follows the setup steps; the bucket name is globally unique and differs for each. A bucket in another region is handled by adding `region` to `backend.hcl`, without editing code.
- **Why not pass `-backend-config="bucket=..."` on the command line?** It works, but must be retyped on every fresh `init`. A file is repeatable and can be reviewed; the template shows what to set.
- **Why encrypt and version the state bucket?** State stores every attribute in plain text, including the database password. Encryption and blocked public access protect it; versioning lets a corrupted or deleted state file be restored.
- **What does missing locking risk?** Two concurrent `apply` runs can both write state, and the last writer wins, losing the other's changes. With one engineer this cannot happen; with a team, add DynamoDB locking (below).
- **What happens when the backend changes?** `terraform init -reconfigure` points at the new backend without copying state; `-migrate-state` copies the existing state across.

## Alternatives to explore

- **DynamoDB locking (`dynamodb_table`):** works on Terraform 1.5, but adds a table to create by hand. Choose this as soon as more than one person runs `apply`.
- **S3-native locking (`use_lockfile`):** no extra table, but needs Terraform 1.10 or later (see ADR 0002).
- **A bootstrap Terraform stack** for the state bucket: removes the manual step, but that stack's own state then needs a home.
- **HCP Terraform:** managed state, locking and run history, at the cost of an external account.
