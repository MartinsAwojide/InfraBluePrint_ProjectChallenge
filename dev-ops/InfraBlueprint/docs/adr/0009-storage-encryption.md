# 0009. Private versioned S3 bucket with SSE-S3 encryption

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

The brief requires a static assets bucket with all public access blocked, versioning enabled, and a name supplied by variable. The EC2 role may use only `s3:GetObject` and `s3:PutObject` (ADR 0007).

## Decision

One bucket, configured with the separate v5 resources: a public access block with all four flags on, versioning enabled, and server-side encryption with SSE-S3 (`AES256`). `force_destroy` stays off.

## Consequences

Objects are encrypted at rest without extra IAM permissions. SSE-KMS would require the role to have KMS permissions, breaking the two-action rule. Versioning protects against overwrites and deletions. With `force_destroy` off, `destroy` fails while the bucket still holds objects or versions, which is a deliberate safeguard for a payments client.

The brief asks that the bucket be reachable only from the EC2 instance's role. The public access block stops all anonymous and public access, and the role's policy is the only grant made by this code. IAM users in the same account who already hold S3 permissions can still reach the bucket; a bucket policy that denies everyone except the role closes that gap, but it can also lock out the account's administrators and Terraform itself, so it is listed below as an alternative.

## Security scanner findings accepted

Checkov flags five things on the bucket. Each is suppressed inline in `main.tf`, because the fix adds resources or cost the brief does not ask for, or contradicts the decision above:

- **CKV_AWS_144, no cross-region replication:** needs a second bucket in another region and a replication role.
- **CKV_AWS_145, not encrypted with KMS:** SSE-S3 is the decision; KMS would need extra permissions on the EC2 role.
- **CKV_AWS_18, no access logging:** needs a separate log bucket (listed below as an alternative).
- **CKV2_AWS_61, no lifecycle configuration:** old versions are kept on purpose; lifecycle rules are listed below as an alternative.
- **CKV2_AWS_62, no event notifications:** nothing in this design consumes bucket events.

## Alternatives to explore

- **SSE-KMS with a customer-managed key:** key rotation, key policies and CloudTrail records of every decrypt. Needs KMS permissions on the role and costs per key and request.
- **Bucket policy requiring TLS and the VPC endpoint:** denies plain-HTTP requests and anything not from the VPC (pairs with the endpoint in ADR 0005).
- **Lifecycle rules:** expire old object versions so versioning doesn't grow storage costs forever.
- **Access logging or CloudTrail data events:** an audit trail of who read or wrote each object.
- **CloudFront in front of the bucket:** the standard way to serve static assets publicly while the bucket stays private.
