# ── Core ──────────────────────────────────────────────────────────────────────

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID — used in repository policy ARNs and pull-through cache URLs."
}

variable "environment" {
  type        = string
  description = "Environment label (dev | staging | prod)."
  default     = "dev"
}

variable "name_prefix" {
  type        = string
  description = "Optional prefix prepended to all repository names (e.g. 'myproduct/')."
  default     = ""
}

# ── Private Repositories ──────────────────────────────────────────────────────

variable "repositories" {
  type        = list(string)
  description = <<-EOT
    Names of private ECR repositories to create. One per service.
    The name_prefix is prepended to each. Examples: ["frontend", "backend", "worker"]
    These are your own application images — not public registry mirrors.
  EOT
  default     = []
}

variable "scan_on_push" {
  type        = bool
  description = "Enable image vulnerability scanning on every push."
  default     = true
}

variable "image_tag_mutability" {
  type        = string
  description = "MUTABLE allows overwriting tags (e.g. 'latest'). IMMUTABLE enforces tag uniqueness."
  default     = "IMMUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

# ── Lifecycle Policy ──────────────────────────────────────────────────────────

variable "lifecycle_tagged_count" {
  type        = number
  description = "Maximum number of tagged images to keep per repository. Oldest beyond this are expired."
  default     = 30
}

variable "lifecycle_untagged_days" {
  type        = number
  description = "Days after which untagged images are expired."
  default     = 7
}

# ── Node Pull Access ──────────────────────────────────────────────────────────

variable "node_role_arns" {
  type        = list(string)
  description = <<-EOT
    EKS node IAM role ARNs to grant pull access via repository policy.
    Leave empty ([]) to skip per-repo policy — access is then controlled by
    the node IAM role policy attached via aj-infra-platform.
  EOT
  default     = []
}

# ── Pull-Through Cache ────────────────────────────────────────────────────────

variable "enable_pull_through_cache" {
  type        = bool
  description = "Create pull-through cache rules for public registries."
  default     = true
}

variable "registries_to_cache" {
  type        = list(string)
  description = <<-EOT
    Public registries to mirror via pull-through cache.
    Available: docker.io, quay.io, ghcr.io, registry.k8s.io, public.ecr.aws
    Pulls go through ECR — avoids rate limits, faster, stays in-region.
  EOT
  default     = ["docker.io", "quay.io", "ghcr.io", "registry.k8s.io", "public.ecr.aws"]
}

variable "pull_through_cache_credentials" {
  type        = map(string)
  description = <<-EOT
    Map of upstream registry → Secrets Manager secret ARN for authentication.
    Required for docker.io (rate limits) and ghcr.io (GitHub packages).
    Not needed for quay.io, registry.k8s.io, or public.ecr.aws.
    Example: {
      "docker.io" = "arn:aws:secretsmanager:us-east-1:123:secret/ecr/dockerhub"
      "ghcr.io"   = "arn:aws:secretsmanager:us-east-1:123:secret/ecr/ghcr"
    }
  EOT
  default     = {}
}

# ── Tags ──────────────────────────────────────────────────────────────────────

variable "team" {
  type    = string
  default = "infra-core"
}

variable "cost_center" {
  type    = string
  default = "infra-2026-q1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
