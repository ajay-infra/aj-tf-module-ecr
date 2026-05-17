# ── Private Repository Outputs ────────────────────────────────────────────────

output "repository_urls" {
  description = "Map of service name → full ECR repository URL. Use as the image registry in Helm values."
  value       = { for name, repo in aws_ecr_repository.app : name => repo.repository_url }
}

output "repository_arns" {
  description = "Map of service name → ECR repository ARN."
  value       = { for name, repo in aws_ecr_repository.app : name => repo.arn }
}

output "ecr_registry_url" {
  description = "Base ECR registry URL for this account and region: <account>.dkr.ecr.<region>.amazonaws.com"
  value       = local.ecr_url
}

# ── Pull-Through Cache Outputs ────────────────────────────────────────────────

output "pull_through_cache_prefixes" {
  description = <<-EOT
    Map of upstream registry → ECR pull-through cache prefix URL.
    Use these prefixes in node configs or OPA allowed-registries policy.
    Example: { "docker.io" = "<account>.dkr.ecr.<region>.amazonaws.com/dockerhub" }
  EOT
  value = {
    for registry, rule in aws_ecr_pull_through_cache_rule.registry :
    registry => "${local.ecr_url}/${rule.ecr_repository_prefix}"
  }
}

# ── IAM Outputs ───────────────────────────────────────────────────────────────

output "node_pull_policy_arn" {
  description = "IAM policy ARN for EKS node ECR pull access. Attach to node role via aj-infra-platform."
  value       = aws_iam_policy.ecr_node_pull.arn
}
