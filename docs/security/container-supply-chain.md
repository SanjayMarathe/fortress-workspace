# Fortress: Container Supply Chain Policy

**Status:** Draft (Phase 0)  
**Related:** [trust-boundaries.md](../architecture/trust-boundaries.md), [ADR-001](../decisions/ADR-001-execution-runtime.md)

## 1. Registry (Amazon ECR)

- **Repositories:** Use **environment-separated** repositories (e.g. `fortress-exec-dev`, `fortress-exec-staging`, `fortress-exec-prod`) to reduce the blast radius of mistaken promotions. Alternative single-repo with strict IAM is acceptable if documented; default recommendation is **separate repos per env**.
- **Immutability:** Enable **image tag immutability** on ECR repositories where tags are used; production **Fargate task definitions must reference image digests**, not mutable tags.
- **Push permissions:** Only **CI roles** (OIDC) may push. Humans use break-glass procedures documented in platform runbooks.

## 2. Signing (Cosign) and keys

- **Signing:** All production-executable images are signed with **Cosign** using a **KMS-backed** private key (see [secrets-identity.md](../architecture/secrets-identity.md)).
- **Verification:** Before an image digest is considered **admissible**, verification MUST succeed:
  - **CI:** Verify immediately after sign and before marking build as promoted artifact.
  - **Control plane (gateway or deployer):** Re-verify digest (or trust CI attestation store) before registering digest as runnable—exact split is an implementation choice in Phase 2, but **at least one** automated verification step is mandatory before production `RunTask`.

## 3. Admission rule (canonical one-liner)

**Fargate may run an image only if its OCI digest is published in the private ECR allowlist for that environment, bears a valid Cosign signature from the Fortress production KMS key (and optional future policy bundle), and satisfies the CVE policy from the linked SBOM build artifact.**

## 4. SBOM (Syft)

- **Generator:** **Syft** runs on every image build in CI.
- **Format (locked for Phase 0):** **SPDX JSON** (single format to avoid tool churn; CycloneDX may be added later only if both are required by a customer—otherwise stay SPDX-only).
- **Storage:** SBOM files stored alongside build metadata (e.g. S3 or artifact registry) with immutable object keys keyed by **image digest**.
- **Scanning:** **Grype** consumes the SPDX SBOM (or image) in CI; failing builds do not promote digests.

**Phase 1 enforcement:** The `fortress-exec-image` GitHub Actions workflow (`.github/workflows/fortress-exec-image.yml`) runs Syft and Grype, then pushes the dev image, Cosign-signs with KMS, and verifies in the same job. Operator steps and variables are in [Phase 1 runbook](../build/phase1-runbook.md).

## 5. “Zero-CVE” operational definition

- **At build time:** Grype report shows **zero Critical and zero High** findings per agreed DB freshness, or an approved exception is recorded.
- **Continuous:** Scheduled or event-driven rescans; if a new finding violates policy, **rebuild and redeploy** per runbook (Phase 5).

## 6. Naming and versioning conventions

- **Image name:** `fortress-exec-<env>` repository, artifact labels include `git_sha`, `build_id`, and **digest** as the sole runtime pin.
- **Policy bundle:** Versioned (git tag or OCI ref) and referenced in verification config.

## 7. References

- [secrets-identity.md](../architecture/secrets-identity.md)  
- [assumptions.md](../architecture/assumptions.md)  
