variable "aws_region" {
  type        = string
  description = "AWS region for ECR, KMS, and IAM resources."
  default     = "us-east-1"
}

variable "github_org" {
  type        = string
  description = "GitHub organization or user (for OIDC trust subject repo:ORG/REPO)."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name without org."
}

variable "project_name" {
  type        = string
  description = "Prefix for resource names."
  default     = "fortress"
}

variable "github_oidc_thumbprints" {
  type        = list(string)
  description = "TLS thumbprints for token.actions.githubusercontent.com (update if GitHub rotates)."
  default = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}
