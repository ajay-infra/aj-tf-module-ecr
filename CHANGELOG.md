# Changelog

All notable changes to this module are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Fixed
- `README.md`'s "Provider pins" table said Terraform `= 1.7.5` — `providers.tf` actually pins `= 1.10.5`, matching the platform-wide Terraform 1.10.5 migration already reflected everywhere else. Same stale-version pattern already found and fixed in `aj-tf-module-vpc`, `aj-tf-module-eks`, `aj-tf-module-aurora`, and `aj-tf-module-valkey`.
- `skills.md`'s "Stable ref" pointed at `github.com/ajaylakma/aj-tf-module-ecr?ref=ecr-01` — wrong org (real org is `ajay-infra`) and a branch that doesn't exist (only `main` — confirmed via `git branch -a`; no tags existed either, despite `README.md`'s own Usage examples already correctly referencing `?ref=v0.1.0`, also nonexistent). Same pattern found repeatedly this project. Fixed both refs to `v1.0.0` and cut that tag (module was fully implemented with no prior release).
- `skills.md`'s "AWS tags applied" listed `Env`, `Team`, `ManagedBy`, `CostCenter`, `Model`, `Customer` — checked `locals.tf`: the real tag set is `Project`/`ManagedBy`/`Repository`/`Environment`/`Team`/`CostCenter` (from `locals.full_tags`) plus whatever's in `var.tags`. No `Env`, `Model`, or `Customer` tag exists anywhere in this module. Same pattern already found in `aj-tf-module-eks`, `aj-tf-module-aurora`, and `aj-tf-module-valkey`.
- `skills.md`'s "Purpose" line claimed "cross-account access for multi-env image promotion pipelines" — grepped the entire module for any cross-account logic: none exists. The actual `repository_policy` in `locals.tf` only grants pull access to `node_role_arns` within the same account. Corrected the description to match what the module actually does (private repos + pull-through cache), and noted explicitly that no cross-account access exists, so nobody plans a feature around a capability that was never built.

## [v1.0.0] - 2026-08-24

Initial release — private ECR repos with lifecycle policies and per-repo node pull policy, pull-through cache for 5 public registries (docker.io, quay.io, ghcr.io, registry.k8s.io, public.ecr.aws). Module was already fully implemented; this tag just formalizes the first stable release so `README.md`/`skills.md` have something real to pin to.
