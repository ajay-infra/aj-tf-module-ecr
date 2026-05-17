locals {
  ecr_url = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  # Full repository names (prefix + service name)
  repo_names = {
    for name in var.repositories :
    name => "${var.name_prefix}${name}"
  }

  # Lifecycle policy JSON — applied to every private repository
  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after ${var.lifecycle_untagged_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.lifecycle_untagged_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last ${var.lifecycle_tagged_count} tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = var.lifecycle_tagged_count
        }
        action = { type = "expire" }
      },
    ]
  })

  # Repository policy — allow EKS node roles to pull
  # Only set when node_role_arns is non-empty
  repository_policy = length(var.node_role_arns) > 0 ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSNodePull"
        Effect = "Allow"
        Principal = {
          AWS = var.node_role_arns
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
        ]
      },
    ]
  }) : null

  # Pull-through cache — upstream registry URLs per ECR namespace prefix
  registry_map = {
    "docker.io"       = "registry-1.docker.io"
    "quay.io"         = "quay.io"
    "ghcr.io"         = "ghcr.io"
    "registry.k8s.io" = "registry.k8s.io"
    "public.ecr.aws"  = "public.ecr.aws"
  }

  # ECR namespace prefix per upstream registry (the local cache path)
  prefix_map = {
    "docker.io"       = "dockerhub"
    "quay.io"         = "quay"
    "ghcr.io"         = "ghcr"
    "registry.k8s.io" = "k8s"
    "public.ecr.aws"  = "ecr-public"
  }

  # Active registries — only those in registries_to_cache
  active_registries = var.enable_pull_through_cache ? {
    for registry in var.registries_to_cache :
    registry => {
      upstream_registry_url = local.registry_map[registry]
      ecr_prefix            = local.prefix_map[registry]
      credential_arn        = lookup(var.pull_through_cache_credentials, registry, null)
    }
    if contains(keys(local.registry_map), registry)
  } : {}

  full_tags = merge({
    Project     = "aj-infra-platform"
    ManagedBy   = "Terraform"
    Repository  = "aj-tf-module-ecr"
    Environment = var.environment
    Team        = var.team
    CostCenter  = var.cost_center
  }, var.tags)
}
