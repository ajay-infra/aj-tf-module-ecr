# CLAUDE.md — aj-tf-module-ecr

> Local context file for Claude Code. Not pushed to GitHub.

---

## What This Module Does

L3 — ECR private repositories + pull-through cache for public registries.
Provisioned once per account, before any cluster or CI pipeline pulls images.

## Where It Fits

**Architecture layer:** L3 — Container Registry
**Provisioned by:** Run once per AWS account before any CI/CD pipeline pushes images
**State key:** `workload/<mode>/<env>/ecr/terraform.tfstate` (planned; not yet wired into provision-eks.yml)
**Consumed by:** All EKS node groups (pull-through cache); CI/CD pipelines (push to private repos)

## How to Use

Not yet wired into the release pipeline. Run manually once per account after the account is set up:

```bash
terraform init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="key=ecr/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="use_lockfile=true"

terraform apply -var-file=envs/prod.tfvars
```

After apply, attach `node_pull_policy_arn` to EKS node IAM roles (this will be automated when wired into `provision-eks.yml`).

Pending: add `docker.io` and `ghcr.io` credentials to Secrets Manager and reference them in `pull_through_cache_credentials` in the tfvars.

## Module Structure

```
locals.tf    → lifecycle policy JSON, repo policy JSON, registry/prefix maps,
               active_registries cross-product
main.tf      → aws_ecr_repository, lifecycle_policy, repository_policy,
               pull_through_cache_rule, iam_policy (node pull)
variables.tf → repositories, pull_through_cache_credentials, node_role_arns, etc.
outputs.tf   → repository_urls, pull_through_cache_prefixes, node_pull_policy_arn
providers.tf → AWS provider with skip_* flags
```

No submodules — for_each on repo names + active_registries handles repetition.

## Key Design Decisions

- **aws_account_id variable** — no data.aws_caller_identity; plan dry run works with skip flags
- **image_tag_mutability = IMMUTABLE in prod** — tags are permanent; no silent overwrites
- **image_tag_mutability = MUTABLE in dev** — allows overwriting branch tags and 'latest'
- **Lifecycle: two rules** — untagged expire after N days; tagged keep last N (independent rules)
- **pull-through cache credential_arn is optional** — public.ecr.aws, quay.io, registry.k8s.io
  need no auth; docker.io and ghcr.io need Secrets Manager credentials for rate limit bypass
- **node_pull_policy_arn output** — aj-infra-platform attaches this to the node IAM role;
  nodes use ecr-credential-provider (built into EKS AMI) — no imagePullSecrets needed
- **OPA allowed-registries** — one entry covers private repos + all pull-through cache
  prefixes since they share the same base ECR domain

## Known TODOs

- [ ] Create docker.io and ghcr.io credentials in Secrets Manager, add to envs/*.tfvars
- [ ] Fill in node_role_arns once EKS clusters are provisioned
- [ ] Add scanning threshold alert — Secrets Manager → SNS when critical vuln found
- [ ] Consider ECR replication for multi-region deployments (future)
