# example.tfvars — CI dry-run plan (no real AWS credentials required)

aws_account_id = "123456789012"
aws_region     = "us-east-1"
environment    = "dev"
name_prefix    = ""

# Service image repositories
repositories = ["frontend", "backend", "worker"]

scan_on_push         = true
image_tag_mutability = "IMMUTABLE"

# Lifecycle
lifecycle_tagged_count  = 30
lifecycle_untagged_days = 7

# No node role ARNs in dry run — repo policies skipped
node_role_arns = []

# Pull-through cache
enable_pull_through_cache = true
registries_to_cache = [
  "docker.io",
  "quay.io",
  "ghcr.io",
  "registry.k8s.io",
  "public.ecr.aws",
]

# No credentials in example — public registries work without creds.
# Add docker.io and ghcr.io creds in envs/*.tfvars using real Secrets Manager ARNs.
pull_through_cache_credentials = {}

team        = "team-0001" # a team code — aj-infra/envs/org/teams.yaml
cost_center = "infra-2026-q1"
