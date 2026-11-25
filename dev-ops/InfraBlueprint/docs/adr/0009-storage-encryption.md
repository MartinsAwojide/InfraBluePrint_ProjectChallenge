# 0009. Private versioned S3 bucket with SSE-S3 encryption

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

The brief requires a static assets bucket with all public access blocked, versioning enabled, and a name supplied by variable. The EC2 role may use only `s3:GetObject` and `s3:PutObject` (ADR 0007).

## Decision

One bucket, configured with the separate v5 resources: a public access block with all four flags on, versioning enabled, and server-side encryption with SSE-S3 (`AES256`). `force_destroy` stays off.

## Consequences

Objects are encrypted at rest without extra IAM permissions. SSE-KMS would require the role to have KMS permissions, breaking the two-action rule. Versioning protects against overwrites and deletions. With `force_destroy` off, `destroy` fails while the bucket still holds objects or versions, which is a deliberate safeguard for a payments client.

## Alternatives to explore

- **SSE-KMS with a customer-managed key:** key rotation, key policies and CloudTrail records of every decrypt. Needs KMS permissions on the role and costs per key and request.
- **Bucket policy requiring TLS and the VPC endpoint:** denies plain-HTTP requests and anything not from the VPC (pairs with the endpoint in ADR 0005).
- **Lifecycle rules:** expire old object versions so versioning doesn't grow storage costs forever.
- **Access logging or CloudTrail data events:** an audit trail of who read or wrote each object.
- **CloudFront in front of the bucket:** the standard way to serve static assets publicly while the bucket stays private.
