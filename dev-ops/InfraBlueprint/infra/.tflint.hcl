# TFLint configuration for InfraBlueprint.
# Run from infra/:  tflint --init  (once), then  tflint
# See docs/adr/0010-tooling.md for why these rulesets were chosen.

# Terraform language rules (bundled with TFLint, no download needed):
# naming conventions, unused declarations, missing types and descriptions.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Not in the recommended preset, but every variable and output must have
# a description, so enforce it.
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

# AWS provider rules: invalid instance types, engine versions, deprecated
# attributes and other errors that only surface at apply time.
# Version pinned for reproducible results. If it reports false positives on
# AWS provider v5 attributes, use 0.40.0, the last release mapped to v5.
plugin "aws" {
  enabled = true
  version = "0.48.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
