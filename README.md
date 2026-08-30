# aj-tf-module-ecr

Terraform module for AWS ECR — private image repositories for application services and pull-through cache rules for public registries. L3 in the platform stack — provisioned per account, before any cluster pulls images.

---

## What this module does

**Private repositories** — one per service (`frontend`, `backend`, `worker`, etc.) with:
- Image vulnerability scanning on every push
- Lifecycle policy (expire untagged after N days, keep last N tagged)
- Optional per-repo pull policy restricting access to named EKS node IAM roles

**Pull-through cache** — mirrors 5 public registries into ECR:

| Upstream | ECR prefix | Why cache it |
|---|---|---|
| `docker.io` | `dockerhub/` | Docker Hub rate limits (100 pulls/6h unauthenticated) |
| `quay.io` | `quay/` | Prometheus, Ceph, many CNCF images |
| `ghcr.io` | `ghcr/` | GitHub Actions runner, ArgoCD plugins |
| `registry.k8s.io` | `k8s/` | CoreDNS, pause, kube-proxy |
| `public.ecr.aws` | `ecr-public/` | AWS-published images (LBC, Karpenter, etc.) |

**IAM policy** — outputs `node_pull_policy_arn` for attachment to EKS node roles via `aj-infra-platform`.

---

## How nodes pull images

EKS AMIs include `ecr-credential-provider` — no `imagePullSecrets` needed. Nodes authenticate with ECR automatically using their IAM role.

```
Pod spec: image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/dockerhub/library/nginx:1.27
                                                                ↑ pull-through prefix ↑
Node:     ecr-credential-provider fetches ECR token via IAM role
ECR:      first pull → fetches from docker.io → caches locally
          subsequent pulls → served from ECR cache
```

For your own images:
```
Pod spec: image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/frontend:v1.2.3
CI:       docker build + docker push → ECR private repo
```

---

## Apply order

ECR is **Stage 3** (L3), provisioned once per account before the cluster:

```
Stage 0:  aj-tf-module-scps     → org guardrails (org-level, management account)
Stage N1: aj-tf-module-vpc      → VPCs (per account, per env)
Stage N2: aj-tf-module-ecr      ← this module (per account, run once)
Stage 1:  aj-tf-module-eks      → EKS cluster
Stage 2:  aj-infra-platform     → attach node_pull_policy_arn to node role
```

ECR is not per-cluster — one set of repos serves all clusters in an account (dev/staging/prod each get their own account and own ECR).

---

## How aj-infra-release uses this module

```bash
# provision-ecr.yml — runs once per account
terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=dev/ecr/terraform.tfstate" \
  -backend-config="region=us-east-1"

terraform apply -var-file=envs/dev.tfvars

# node_pull_policy_arn output → passed to aj-infra-platform as a variable
# so it can attach the policy to the EKS node IAM role
```

---

## Usage

### Minimal — private repos + all pull-through caches

```hcl
module "ecr" {
  source = "github.com/ajay-infra/aj-tf-module-ecr?ref=v1.0.0"

  aws_account_id = "123456789012"
  environment    = "dev"
  repositories   = ["frontend", "backend", "worker"]
}
```

### With authenticated pull-through cache (docker.io rate limits)

```hcl
module "ecr" {
  source = "github.com/ajay-infra/aj-tf-module-ecr?ref=v1.0.0"

  aws_account_id = "123456789012"
  environment    = "prod"
  repositories   = ["frontend", "backend", "worker"]

  pull_through_cache_credentials = {
    "docker.io" = "arn:aws:secretsmanager:us-east-1:123456789012:secret/ecr/dockerhub-abc123"
    "ghcr.io"   = "arn:aws:secretsmanager:us-east-1:123456789012:secret/ecr/ghcr-def456"
  }

  node_role_arns = [
    "arn:aws:iam::123456789012:role/prod-blue-eks-node-role",
  ]
}
```

### Using envs/ files (release pipeline style)

```bash
terraform apply -var-file=envs/dev.tfvars
```

---

## OPA allowed-registries policy

Update the `allowed-registries` OPA Gatekeeper constraint in `aj-cluster-baseline` to permit your ECR registry and all pull-through cache prefixes:

```yaml
# aj-cluster-baseline/constraints/allowed-registries.yaml
spec:
  parameters:
    allowedRegistries:
      - "123456789012.dkr.ecr.us-east-1.amazonaws.com"
      # Above covers: private repos + all pull-through cache prefixes
```

All pull-through cache URLs share the same account ECR domain — one entry covers all of them.

---

## Docker Hub credential setup (one-time)

Docker Hub rate limits unauthenticated pulls. To avoid throttling in CI and production:

1. Create a Docker Hub account and generate an access token
2. Store in Secrets Manager:
   ```bash
   aws secretsmanager create-secret \
     --name ecr/dockerhub \
     --secret-string '{"username":"<dockerhub-user>","accessToken":"<token>"}'
   ```
3. Pass the ARN in `pull_through_cache_credentials.docker.io`

Same pattern for `ghcr.io` using a GitHub fine-grained PAT with `read:packages` scope.

---

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `aws_account_id` | yes | — | AWS account ID — used in repo policy ARNs and cache URLs |
| `environment` | no | `dev` | Environment label for tags and IAM policy name |
| `aws_region` | no | `us-east-1` | AWS region |
| `repositories` | no | `[]` | Service names for private ECR repos |
| `name_prefix` | no | `""` | Optional prefix for all repo names |
| `scan_on_push` | no | `true` | Enable image vulnerability scanning |
| `image_tag_mutability` | no | `IMMUTABLE` | `IMMUTABLE` (prod) or `MUTABLE` (dev/staging) |
| `lifecycle_tagged_count` | no | `30` | Max tagged images to keep |
| `lifecycle_untagged_days` | no | `7` | Days before untagged images are expired |
| `node_role_arns` | no | `[]` | EKS node IAM role ARNs for per-repo pull policy |
| `enable_pull_through_cache` | no | `true` | Create pull-through cache rules |
| `registries_to_cache` | no | all 5 | Which public registries to mirror |
| `pull_through_cache_credentials` | no | `{}` | Map of `registry → Secrets Manager ARN` |

---

## Outputs

| Output | Description |
|---|---|
| `repository_urls` | Map of `service → ECR URL` — use as `image.repository` in Helm values |
| `repository_arns` | Map of `service → ECR ARN` |
| `ecr_registry_url` | Base registry URL: `<account>.dkr.ecr.<region>.amazonaws.com` |
| `pull_through_cache_prefixes` | Map of `upstream registry → ECR cache prefix URL` |
| `node_pull_policy_arn` | IAM policy ARN — attach to EKS node role via `aj-infra-platform` |

---

## Provider pins

| Tool | Version |
|---|---|
| Terraform | `= 1.10.5` |
| AWS provider | `= 5.100.0` |
