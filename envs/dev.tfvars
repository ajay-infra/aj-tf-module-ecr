# envs/dev.tfvars — dev account ECR

aws_account_id = "REPLACE_WITH_DEV_ACCOUNT_ID"
aws_region     = "us-east-1"
environment    = "dev"
name_prefix    = ""

repositories = ["frontend", "backend", "worker"]

scan_on_push         = true
image_tag_mutability = "MUTABLE" # MUTABLE in dev — allows overwriting 'latest' and branch tags

lifecycle_tagged_count  = 10 # fewer in dev — less storage cost
lifecycle_untagged_days = 3

# EKS node role ARNs — fill in after cluster is provisioned
node_role_arns = []

enable_pull_through_cache = true
registries_to_cache = [
  "docker.io",
  "quay.io",
  "ghcr.io",
  "registry.k8s.io",
  "public.ecr.aws",
]

# Add docker.io and ghcr.io credential ARNs once created in Secrets Manager
pull_through_cache_credentials = {
  # "docker.io" = "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret/ecr/dockerhub"
  # "ghcr.io"   = "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret/ecr/ghcr"
}

team        = "infra-core"
cost_center = "infra-2026-q1"
