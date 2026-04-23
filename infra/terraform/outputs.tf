output "ecr_exec_dev_repository_url" {
  value       = aws_ecr_repository.exec_dev.repository_url
  description = "ECR URL for fortress-exec-dev (push target for CI on main)."
}

output "ecr_exec_staging_repository_url" {
  value       = aws_ecr_repository.exec_staging.repository_url
  description = "ECR URL for fortress-exec-staging."
}

output "ecr_exec_prod_repository_url" {
  value       = aws_ecr_repository.exec_prod.repository_url
  description = "ECR URL for fortress-exec-prod."
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_image.arn
  description = "Set as GitHub variable AWS_ROLE_TO_ASSUME for fortress-exec-image workflow."
}

output "cosign_kms_key_arn" {
  value       = aws_kms_key.cosign.arn
  description = "Cosign KMS signer ARN (awskms:///… URI)."
}

output "cosign_kms_key_id" {
  value       = aws_kms_key.cosign.key_id
  description = "KMS key id (UUID portion of ARN)."
}
