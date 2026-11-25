# Architecture Decision Records

Each file records one decision: the context, what was chosen, what it costs, and which alternatives are worth exploring if requirements change. New decisions get the next number. A decision is never edited away; it is superseded by a new ADR.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](./0001-record-architecture-decisions.md) | Record decisions as ADRs | Accepted |
| [0002](./0002-terraform-version.md) | Develop on Terraform 1.5.7, AWS provider `~> 5.0` | Accepted |
| [0003](./0003-flat-root-module.md) | Flat root module in three files (`main.tf`, `variables.tf`, `outputs.tf`) | Accepted |
| [0004](./0004-remote-state-partial-backend.md) | S3 remote state with partial backend config | Accepted |
| [0005](./0005-network-layout.md) | Two-AZ VPC, private RDS subnets, no NAT Gateway | Accepted |
| [0006](./0006-security-group-rules.md) | Standalone security group rules, SG-to-SG reference for the database | Accepted |
| [0007](./0007-compute-and-iam.md) | Instance profile with two S3 actions, IMDSv2, AMI lookup | Accepted |
| [0008](./0008-database.md) | Single-AZ private RDS, credentials from variables | Accepted |
| [0009](./0009-storage-encryption.md) | Private versioned bucket with SSE-S3 | Accepted |
| [0010](./0010-tooling.md) | fmt, TFLint and Checkov, with uv for Python tooling | Accepted |
| [0011](./0011-testing-strategy.md) | Test the plan with pytest, against a local emulator first | Accepted |

New ADRs start from [`0000-template.md`](./0000-template.md).
