# 0003. Use a flat root module in three files

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

The infrastructure is small: one VPC, one instance, one database and one bucket, for a single environment. It must be built and reviewed within two days. The starter code provides `main.tf`, `variables.tf` and `outputs.tf`, and the brief asks for `variables.tf` and `outputs.tf` by name.

## Decision

Keep all resources in a single root module in `infra/`, in the starter's three files: `main.tf` for every resource and data source, organised into commented sections (settings, provider, networking, security groups, compute, database, storage), plus `variables.tf` and `outputs.tf`. Any other structure is decided later, by the optional improvement chosen after the core is complete.

## Consequences

The layout matches what reviewers expect from the starter, every resource is in one place, resource addresses stay simple, and there is no module interface to design or debug. The cost is a long `main.tf` (navigable through its section headers) and no reuse: a second environment or a second application would mean copying code.

## Alternatives to explore

- **One file per concern** (`network.tf`, `security.tf`, and so on): easier navigation as the file grows, at the cost of departing from the starter layout.
- **Child modules** (networking, compute, database, storage): the brief's modules bonus. Better reuse and clearer boundaries, but every resource address and output reference changes. Worth it once a second environment or service appears.
- **Registry modules** such as `terraform-aws-modules/vpc`: less code, but hides the networking details this challenge is meant to show.
- **Per-environment tfvars or workspaces:** the multi-environment bonus. Adds files beside the three, without changing them.
