# skills.md — aj-tf-module-ecr

## Purpose
Provisions ECR repositories with image scanning, lifecycle policies, and cross-account access for multi-env image promotion pipelines.

## Type
`tf-module`

## Stable ref
```
source = "github.com/ajaylakma/aj-tf-module-ecr?ref=ecr-01"
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
`Env`, `Team`, `ManagedBy`, `CostCenter`, `Model`, `Customer`

## Branching convention
- `main` — active development
- `ecr-01` — stable pinned release

## CI checks
fmt, validate, plan (dry-run), tfsec/checkov

## Agentic capabilities
- Detect repositories with image_tag_mutability=MUTABLE in prod
- Flag scan_on_push=false
- Generate PR to add new repository when service is onboarded
- Check lifecycle policy retains enough images for rollback (min 5)
