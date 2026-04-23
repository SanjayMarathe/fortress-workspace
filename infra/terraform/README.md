# Fortress Phase 1 — minimal AWS (ECR, KMS, GitHub OIDC)

Creates three ECR repositories (`fortress-exec-dev`, `fortress-exec-staging`, `fortress-exec-prod`), one asymmetric KMS key for Cosign (`alias/fortress-cosign-signing`), and an IAM role assumable from GitHub Actions on **pushes to `main`** for the configured repo.

## Prerequisites

- Terraform >= 1.5
- AWS credentials with permissions to create ECR, KMS, and IAM OIDC resources

## Usage

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GitHub org and repo name.

terraform init
terraform apply
```

Copy outputs into GitHub **repository variables** (see [docs/build/phase1-runbook.md](../../docs/build/phase1-runbook.md)):

- `AWS_ROLE_TO_ASSUME` = `github_actions_role_arn`
- `COSIGN_KMS_ARN` = `cosign_kms_key_arn`
- `AWS_REGION` = same as `var.aws_region`

## OIDC provider already exists

If `terraform apply` fails because `aws_iam_openid_connect_provider.github` already exists in the account, import it instead of creating:

```bash
terraform import 'aws_iam_openid_connect_provider.github' 'arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com'
```

Then remove the `resource "aws_iam_openid_connect_provider" "github"` block from `main.tf` and replace with a `data` source only if your Terraform AWS provider version supports it, or keep the imported resource in state. The simplest path is **import once** and keep the resource block so state matches.

## Thumbprints

If GitHub rotates certificates, update `github_oidc_thumbprints` in `variables.tf` or override in `terraform.tfvars`.
