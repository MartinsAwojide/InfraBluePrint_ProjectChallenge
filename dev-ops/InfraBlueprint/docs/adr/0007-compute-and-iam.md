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

The provider's default tags do not reach the root volume, so the `Project` tag is set inside `root_block_device`; a test checks it.

## Questions this decision raises

- **Why look up the AMI instead of pinning an ID?** AMI IDs exist in one region only and change with each Amazon Linux release. The lookup lets the same code plan in any region `aws_region` names.
- **Why `owners = ["amazon"]`?** Anyone can publish a public AMI with a matching name. Restricting the owner ensures the image comes from Amazon, not an impostor.
- **What is the weak spot?** `most_recent = true` means a new AMI release changes the instance's `ami`, and Terraform plans to replace the instance. For production, pin the ID or add `lifecycle { ignore_changes = [ami] }` and roll images deliberately.
- **Why the `x86_64` filter?** Without it the lookup can return an ARM (`arm64`) image, which `t2.micro` cannot boot.
- **Why IMDSv2?** The instance profile removes keys from disk, but with IMDSv1 any server-side request forgery bug can read the role's credentials with one GET request. IMDSv2 requires a PUT for a session token first, which blocks that.

## Security scanner findings accepted

- **CKV_AWS_126, detailed monitoring off:** detailed (one-minute) monitoring is billed per instance; basic five-minute monitoring is free and enough here. Suppressed inline.
- **CKV_AWS_135, not EBS-optimized:** `t2.micro` does not support EBS optimization, and the brief requires `t2.micro`. Suppressed inline.

## Alternatives to explore

- **Pin the AMI ID:** stable plans with no surprise replacements, but manual updates and region-specific IDs.
- **SSM Parameter Store AMI lookup:** AWS's recommended way to find the latest AMI, but it needs `ssm:GetParameter` permission for reviewers.
- **Add `s3:ListBucket`:** clearer errors for applications, but outside the brief's two-action limit.
- **Attach `AmazonSSMManagedInstanceCore`:** enables Session Manager (see ADR 0006) and patch management.
- **Newer instance family** (`t3.micro`, `t4g.micro` on ARM): cheaper or faster, and covered by newer free-tier plans, but the brief specifies `t2.micro`.
