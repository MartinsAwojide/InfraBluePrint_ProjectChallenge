# 0007. EC2 with an instance profile limited to two S3 actions

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

The brief requires a `t2.micro` Amazon Linux 2023 instance in a public subnet, with an IAM instance profile allowing only `s3:GetObject` and `s3:PutObject` on the project bucket. AMI IDs differ per region and change with every release.

## Decision

- AMI from an `aws_ami` data source: newest Amazon-owned image matching `al2023-ami-2023.*-x86_64`. The `x86_64` filter matters, because `t2.micro` cannot run ARM images.
- IMDSv2 enforced (`http_tokens = "required"`) and the root volume encrypted.
- An IAM role trusted only by `ec2.amazonaws.com`, with one inline policy granting the two actions on `<bucket ARN>/*`, attached through an instance profile.

## Consequences

The instance gets short-lived, automatically rotated credentials, and no access keys exist to leak. IMDSv2 blocks the classic SSRF route to those credentials. The AMI updates automatically on each plan, which also means a new AMI release will show the instance as needing replacement. Without `s3:ListBucket`, a request for a missing object returns 403 rather than 404.

## Alternatives to explore

- **Pin the AMI ID:** stable plans with no surprise replacements, but manual updates and region-specific IDs.
- **SSM Parameter Store AMI lookup:** AWS's recommended way to find the latest AMI, but it needs `ssm:GetParameter` permission for reviewers.
- **Add `s3:ListBucket`:** clearer errors for applications, but outside the brief's two-action limit.
- **Attach `AmazonSSMManagedInstanceCore`:** enables Session Manager (see ADR 0006) and patch management.
- **Newer instance family** (`t3.micro`, `t4g.micro` on ARM): cheaper or faster, and covered by newer free-tier plans, but the brief specifies `t2.micro`.
