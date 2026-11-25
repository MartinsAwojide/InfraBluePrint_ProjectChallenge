# 0001. Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

Vela Payments' original infrastructure was built by hand, and nobody knew why it looked the way it did once its lead engineer left. Code alone records what exists, not why.

## Decision

Record each significant decision as a short ADR in `docs/adr/`, committed alongside the code it explains.

## Consequences

The next engineer can see why a choice was made and which alternatives were considered. Each ADR costs a few minutes to write.

## Alternatives to explore

- **Design notes in the README only:** less overhead, but decisions get lost as the README is rewritten.
- **Comments in the Terraform code:** good for single settings, poor for decisions spanning several files.
