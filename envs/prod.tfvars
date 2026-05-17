# envs/prod.tfvars — prod account ECR

aws_account_id = "REPLACE_WITH_PROD_ACCOUNT_ID"
aws_region     = "us-east-1"
environment    = "prod"
name_prefix    = ""

repositories = ["frontend", "backend", "worker"]

scan_on_push         = true
image_tag_mutability = "IMMUTABLE" # IMMUTABLE in prod — tags are permanent

lifecycle_tagged_count  = 30
lifecycle_untagged_days = 7

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

pull_through_cache_credentials = {
  # "docker.io" = "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret/ecr/dockerhub"
  # "ghcr.io"   = "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret/ecr/ghcr"
}

team        = "infra-core"
cost_center = "infra-2026-q1"
