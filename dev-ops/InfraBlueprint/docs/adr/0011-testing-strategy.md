# 0011. Test the plan with pytest, against a local emulator first

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

The infrastructure should be built test-first, with each requirement checked automatically. Terraform's built-in `terraform test` command needs Terraform 1.6 or later, but this project develops on 1.5.7 (ADR 0002). Testing against real AWS is slow, needs credentials, and costs money once anything is applied.

LocalStack's free Community edition ended on 23 March 2026: its image now requires an account and auth token, and its free Hobby plan is for non-commercial use only. Its database emulation was already a paid feature. floci is an MIT-licensed emulator on the same port (4566) that needs no account or token, and emulates EC2 (with VPC resources), IAM, STS, RDS (backed by real PostgreSQL containers) and S3, with Terraform support.

## Decision

- **Plan tests in pytest**, run through uv. Each test reads the output of `terraform show -json` and checks one requirement: literal values from planned values, and references (for example, the SSH rule using `var.allowed_ssh_cidr`) from the configuration section.
- **Every test run uses a disposable copy of `infra/`** in a temporary directory, with an override file that switches to local state and, for the emulator, points the provider at it. The real Terraform files and the remote state are never touched.
- **floci is the default target**: free, offline, no AWS account. The same plan tests can run read-only against real AWS (`make test-aws`) to cover anything the emulator lacks.
- **Integration tests apply to floci only.** The fixture refuses any endpoint other than localhost, then destroys everything it created.

## Consequences

Requirements become executable checks, written before the code that satisfies them. The tests are part of the local development workflow and are not committed; the repository stays limited to the infrastructure code and its documentation. The default test run costs nothing and needs no credentials. Because plan tests read the JSON plan, they survive a later refactor into modules. The costs: Docker is required, the emulator socket mount gives floci root-level control of Docker on the machine, and floci's published Terraform compatibility tests start at Terraform 1.10, so behaviour on 1.5.7 (and of the Amazon Linux AMI lookup) must be proven with an early trial run. An emulator can also accept configuration that real AWS would reject, which is why `make test-aws` stays in the final checks before submission.

## Trial run result (2026-11-25)

A plan of a throwaway VPC plus the availability zone and Amazon Linux 2023 AMI lookups against floci, on Terraform 1.5.7 with AWS provider 5.100.0, succeeded. The zone lookup returned `us-east-1a`, `us-east-1b` and `us-east-1c`. The AMI lookup returned a placeholder image ID (`ami-0abcdef1234567891`), so tests can check that the instance uses the lookup, but not which image AWS would choose. The real image is checked by `make test-aws`. No tests need to be marked as expected failures so far.

## Alternatives to explore

- **`terraform test`:** native, with mocked providers in newer versions, but needs Terraform 1.6 or later, which breaks the 1.5.7 floor (ADR 0002).
- **Terratest:** the established Go library for applying real infrastructure in tests. Powerful, but adds a Go toolchain and normally runs against real AWS.
- **Policy as code (Conftest with OPA, or custom Checkov policies):** good for organisation-wide rules on plans; less natural for checking this project's specific values.
- **LocalStack with a Hobby or paid plan:** mature and widely documented, but needs an account and token, and the free plan excludes commercial use.
- **moto server:** a Python AWS mock, light and free, but with shallower EC2, VPC and RDS behaviour than floci.
- **Plan tests against real AWS only:** no Docker needed and real data sources, but always needs credentials.
