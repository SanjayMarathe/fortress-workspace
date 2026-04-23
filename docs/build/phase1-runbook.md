# Fortress Phase 1 — Build, SBOM, Grype, ECR, Cosign

This runbook matches the implementation under `build/`, `infra/terraform/`, and `.github/workflows/fortress-exec-image.yml`.

## What Phase 1 delivers

- **Melange** recipe [`build/melange/fortress-exec.yaml`](../../build/melange/fortress-exec.yaml) producing APK `fortress-runner` (installs [`build/runner/runner.py`](../../build/runner/runner.py)).
- **apko** image [`build/apko/fortress-exec.yaml`](../../build/apko/fortress-exec.yaml): Wolfi base, `python-3.12-base`, non-root entrypoint `python3 /usr/lib/fortress/runner.py`.
- **CI** on pushes to `main` when `build/**` changes: Syft SPDX JSON, Grype gate (`--fail-on high`), push to **dev** ECR, Cosign **KMS** sign and verify.
- **Terraform** minimal stack: three ECR repos, one ECC P-256 KMS key, GitHub OIDC role for the workflow.

## Prerequisites (local, no AWS)

- Docker (daemon running), network access to `ghcr.io` and `packages.wolfi.dev`.

## Local build and scan (no push)

From the repository root:

```sh
chmod +x build/scripts/build-image.sh
./build/scripts/build-image.sh
```

Install pinned Syft and Grype (versions match the workflow), then:

```sh
syft packages "oci-archive:$(pwd)/dist/fortress-exec.tar" -o "spdx-json=$(pwd)/dist/sbom.spdx.json"
grype "sbom:$(pwd)/dist/sbom.spdx.json" -o table --fail-on high
```

If **Melange** cannot resolve `python-3.12-base`, Wolfi may have moved to a newer Python line; update [`build/melange/fortress-exec.yaml`](../../build/melange/fortress-exec.yaml) and [`build/apko/fortress-exec.yaml`](../../build/apko/fortress-exec.yaml) in lockstep and bump the Melange `epoch` when changing the runner package without a version bump.

## AWS and GitHub setup

1. Apply Terraform from [`infra/terraform/README.md`](../../infra/terraform/README.md) with your `github_org` and `github_repo`.
2. In the GitHub repository, add **Variables** (Settings → Secrets and variables → Actions → Variables):

| Variable | Example source |
|----------|----------------|
| `AWS_REGION` | Same as Terraform `aws_region` |
| `AWS_ROLE_TO_ASSUME` | Terraform output `github_actions_role_arn` |
| `COSIGN_KMS_ARN` | Terraform output `cosign_kms_key_arn` (full `arn:aws:kms:…`) |
| `ECR_DEV_REPOSITORY_URL` | Terraform output `ecr_exec_dev_repository_url` (`ACCOUNT.dkr.ecr.REGION.amazonaws.com/fortress-exec-dev`) |

3. Ensure GitHub Actions **OIDC** is allowed for this repository (no enterprise OIDC restrictions blocking `token.actions.githubusercontent.com`).

The workflow **fails early** if any of these variables are unset.

## Troubleshooting

- **Privileged Docker:** Melange inside the Wolfi SDK container needs `--privileged` (used in CI and `build-image.sh`).
- **ECR OIDC trust:** The IAM role trusts only `refs/heads/main` for `repo:ORG/REPO`. Adjust [`infra/terraform/main.tf`](../../infra/terraform/main.tf) if you use a different default branch.
- **Cosign KMS URI:** The workflow uses `awskms:///${COSIGN_KMS_ARN}` (note the third `/` before the ARN).
- **“No shell” in prod:** If Grype/Syft show a shell pulled in transitively, capture the SBOM and record the finding per [ADR-001](../decisions/ADR-001-execution-runtime.md) footnote.

## Related policy docs

- [Container supply chain policy](../security/container-supply-chain.md) — how CI maps to admission rules.
- [ADR-001 — execution runtime](../decisions/ADR-001-execution-runtime.md)
