# ── Private ECR Repositories ──────────────────────────────────────────────────
# One repository per service. Images tagged IMMUTABLE by default —
# no silent overwrites of existing tags in prod.

resource "aws_ecr_repository" "app" {
  for_each = local.repo_names

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(local.full_tags, { Service = each.key })
}

# Lifecycle policy — expire old images to control storage cost
resource "aws_ecr_lifecycle_policy" "app" {
  for_each = local.repo_names

  repository = aws_ecr_repository.app[each.key].name
  policy     = local.lifecycle_policy
}

# Repository policy — restrict pull to named EKS node IAM roles
# Skipped when node_role_arns = [] (access controlled via node IAM role policy instead)
resource "aws_ecr_repository_policy" "app" {
  for_each = length(var.node_role_arns) > 0 ? local.repo_names : {}

  repository = aws_ecr_repository.app[each.key].name
  policy     = local.repository_policy
}

# ── Pull-Through Cache Rules ──────────────────────────────────────────────────
# Mirror public registries into ECR to avoid rate limits and reduce pull latency.
# Images are cached regionally — first pull fetches from upstream, subsequent
# pulls serve from ECR cache. Nodes use ecr-credential-provider (built into EKS AMI).
#
# Pull syntax:
#   docker.io/library/nginx:1.27  →  <account>.dkr.ecr.<region>.amazonaws.com/dockerhub/library/nginx:1.27
#   ghcr.io/actions/runner:2.323  →  <account>.dkr.ecr.<region>.amazonaws.com/ghcr/actions/runner:2.323
#   registry.k8s.io/pause:3.9    →  <account>.dkr.ecr.<region>.amazonaws.com/k8s/pause:3.9

resource "aws_ecr_pull_through_cache_rule" "registry" {
  for_each = local.active_registries

  ecr_repository_prefix = each.value.ecr_prefix
  upstream_registry_url = each.value.upstream_registry_url

  # credential_arn is required for authenticated registries (docker.io, ghcr.io)
  # Optional for public registries (quay.io, registry.k8s.io, public.ecr.aws)
  credential_arn = each.value.credential_arn
}

# ── IAM Policy for EKS Nodes ──────────────────────────────────────────────────
# Attach this policy to the EKS node IAM role (via aj-infra-platform Pod Identity
# or directly on the node role) to allow pulling from ECR.
#
# Pull-through cache needs TWO permissions beyond a normal pull, and granting
# only one of them fails in a way nothing catches until a real first pull:
#
#   ecr:CreateRepository        ECR auto-creates the cached repository namespace
#                               the first time an image is pulled through it.
#   ecr:BatchImportUpstreamImage  copies the image from the upstream registry
#                               into that repository. WITHOUT THIS, the first
#                               pull of any uncached image is denied — and every
#                               pull is a first pull until the cache warms.
#
# The second was missing. The comment above it explained why the first was
# needed and stopped one action short, which is why the gap survived: the
# reasoning was written down and was half complete.

resource "aws_iam_policy" "ecr_node_pull" {
  name        = "${var.environment}-ecr-node-pull"
  description = "Allow EKS nodes to pull images from ECR private repos and pull-through cache"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages",
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/*"
      },
      {
        Sid    = "ECRPullThroughCache"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:BatchImportUpstreamImage",
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/*"
      },
    ]
  })

  tags = local.full_tags
}
