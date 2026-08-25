# skills.md — aj-tf-module-ecr

## Purpose
Provisions ECR repositories with image scanning, lifecycle policies, and pull-through
cache rules for public registries (docker.io, quay.io, ghcr.io, registry.k8s.io,
public.ecr.aws). One account, one set of repos — not per-cluster. No cross-account
repository access exists in this module; the repository policy only grants pull access
to node IAM role ARNs within the same account.

## Type
`tf-module`

## Stable ref
```
source = "github.com/ajay-infra/aj-tf-module-ecr?ref=v1.0.0"
```

## Key inputs
| Variable | Description |
|---|---|
| `environment` | dev \| staging \| uat \| prod |
| `name_prefix` | Repository name prefix |
| `repositories` | List of repository names |
| `scan_on_push` | Enable image vulnerability scanning |
| `image_tag_mutability` | MUTABLE \| IMMUTABLE |
| `lifecycle_tagged_count` | Max tagged images to retain |

## AWS tags applied
`Project`, `ManagedBy`, `Repository`, `Environment`, `Team`, `CostCenter` (set in
`locals.full_tags`), plus whatever's in `var.tags`. No `Env`, `Model`, or `Customer`
tag exists in this module.

## Branching convention
- `main` — active development
- semver tags (`v1.0.0`, ...) — stable pinned releases, per `README.md` usage examples

## CI checks
fmt, validate, plan (dry-run), tfsec/checkov

## Agentic capabilities
- Detect repositories with image_tag_mutability=MUTABLE in prod
- Flag scan_on_push=false
- Generate PR to add new repository when service is onboarded
- Check lifecycle policy retains enough images for rollback (min 5)
