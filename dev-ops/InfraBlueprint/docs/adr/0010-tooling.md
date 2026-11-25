# 0010. Lint and scan with fmt, TFLint and Checkov, using uv for Python tooling

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

`terraform validate` checks syntax and references, but not provider-specific errors (an invalid instance type, a deprecated attribute) or security misconfigurations. Reviewers also judge readability. The tooling must stay lean and reproducible.

## Decision

- **`terraform fmt`** for canonical formatting.
- **TFLint** with the bundled `terraform` ruleset (`recommended` preset) and the AWS ruleset, version-pinned in `infra/.tflint.hcl`.
- **Checkov** for security scanning, installed through **uv** from `pyproject.toml`, with exact versions in `uv.lock`.
- **One uv environment for every tool.** `bootstrap.sh` (run by `make setup`) installs Checkov through uv, then downloads Terraform and TFLint into `.venv/bin`, verifying each checksum. uv is the only prerequisite, and `uv run` gives every command the same tool versions.
- A **Makefile** with `setup`, `fmt`, `check` and `plan` targets, so every check is one command.

## Consequences

These tools are a local development workflow and are not committed: the repository holds only the Terraform, its configuration and the documentation, so reviewers need nothing beyond Terraform. Checks run without AWS credentials, apart from `plan`. Versions are reproducible: Terraform through `.terraform-version`, TFLint plugins through `.tflint.hcl`, Checkov through `uv.lock`. Checkov reports many best-practice findings the brief doesn't require; each is either fixed with a setting or suppressed inline with a reason, never by adding unrequested infrastructure. `make` is not installed by default on Windows.

## Alternatives to explore

- **Homebrew, tenv or mise for the binaries:** familiar system-wide installs, but versions then vary between machines.
- **pre-commit hooks:** run the same checks on every commit. The config must live at the fork's repository root, outside this folder.
- **Trivy** (which absorbed tfsec): a single binary security scanner, with no Python environment.
- **terraform-docs:** generates the README variable table straight from `variables.tf`, so it never drifts.
- **GitHub Actions CI:** runs `make check` on every push, so reviewers see a green build.
- **TFLint AWS deep checking** (`deep_check = true` in the plugin block): validates values against live AWS APIs, but needs credentials.
