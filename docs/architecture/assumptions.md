# Fortress: Phase 0 Assumption Log

**Status:** Draft  
**Owner:** Sanjay Marathe

These assumptions constrain Phase 1–2 work. If any change, file an ADR update.

## 1. AWS account model (minimal infra)

- **Default for v1:** **One AWS account** to keep provisioning and billing simple. Environments (**dev**, **staging**, **prod**) are separated by **naming conventions**, **IAM roles/policies**, and **distinct resources** (e.g. separate ECR repositories or ECS clusters per env)—not by account boundary.
- **Signing (Cosign/KMS):** Prefer **one KMS signing key** for the whole account until traffic warrants splitting; optionally add a **second key** reserved for prod-only images if you want a cleaner promotion story without a second account.
- **When to add more accounts:** Defer multi-account (e.g. prod vs everything else) until compliance or blast-radius requirements force it; document the migration in an ADR when adopted.

## 2. Regions

- **v1 default:** **Single primary region** for Fortress control plane and Fargate workloads (e.g. `us-east-1` or org standard), documented per deployment.
- **Multi-region:** Not required for v1; DR and multi-region active/active are out of scope unless explicitly funded.

## 3. Meaning of “air-gapped” for v1

- **In scope for v1 wording:** **Network isolation of Fargate execution tasks** from the public internet (default-deny egress, optional VPC endpoints for required AWS APIs only). This matches “decouple Brain from execution” without claiming a fully disconnected data center.
- **Out of scope for v1 unless separately funded:** **Full corporate air-gap** (no internet in build CI, physical media transfers, on-prem registry mirrors). If required later, add ADR for mirrored ECR, offline Grype DB, and offline Cosign/TUF infrastructure.

## 4. Identity for human operators

- **Assumption:** Human access to AWS and CI is via **SSO** and **OIDC**-federated roles; no long-lived IAM user access keys for day-to-day work.

## 5. References

- [trust-boundaries.md](./trust-boundaries.md)  
- [data-flows.md](./data-flows.md)  
- [container-supply-chain.md](../security/container-supply-chain.md)  
