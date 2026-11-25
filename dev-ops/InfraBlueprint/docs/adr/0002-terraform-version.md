# 0002. Develop on Terraform 1.5.7 with AWS provider `~> 5.0`

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

The starter code sets `required_version = ">= 1.5"` and the AWS provider to `~> 5.0`, and the brief asks for Terraform 1.5 or later. Reviewers may use any version from 1.5 upward. Code written on a newer version can silently use features that fail on 1.5, such as `use_lockfile` (1.10), `removed` blocks (1.7) or provider-defined functions (1.8).

## Decision

Develop and test on exactly Terraform **1.5.7**, the final 1.5 release, pinned in `infra/.terraform-version`. Version managers such as tenv and tfenv read that file, as does the local setup script used during development. In code, keep `required_version = ">= 1.5.0, < 2.0.0"` and the AWS provider at `~> 5.0`.

## Consequences

Testing on the oldest allowed version means anything that passes locally passes for every reviewer. The cost is no access to newer conveniences, most notably S3-native state locking. The provider constraint excludes AWS provider 6.x and its breaking changes. The dependency lock file stays gitignored, matching the starter template, so reviewers receive the newest 5.x provider rather than the exact build tested.

## Alternatives to explore

- **Develop on the latest Terraform:** newer features and better error messages, but compatibility with 1.5 must then be checked by hand.
- **Raise the floor to 1.10:** enables `use_lockfile` for state locking without DynamoDB, but breaks reviewers on older versions. Only worth it if AmaliTech confirms their version.
- **Commit `.terraform.lock.hcl`:** HashiCorp's recommendation; pins the exact provider build for reviewers. Requires removing it from the starter's ignore list.
- **OpenTofu:** open-source fork, but reviewers expect Terraform.
