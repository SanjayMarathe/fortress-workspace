# Fortress: Secrets and Identity Matrix

**Status:** Draft (Phase 0)  
**Companion:** [trust-boundaries.md](./trust-boundaries.md), [data-flows.md](./data-flows.md)

This matrix is the inventory for Phase 2 IAM and Phase 1 CI signing work. Store secrets in **AWS Secrets Manager** or **SSM Parameter Store** (SecureString) as appropriate; prefer **IAM roles** over static keys where possible.

## 1. Matrix

| Secret / credential | Owner component | Storage | Rotation owner | Read by | Notes |
|--------------------|-----------------|---------|----------------|---------|-------|
| **Cosign KMS signing key** | Platform / security | AWS KMS (asymmetric, signing) | Security / platform | CI pipeline (OIDC to role), optional break-glass human | **Never** mount into Fargate execution tasks for v1 |
| **Cosign verification policy bundle** | Platform | S3 versioned bucket or OCI registry policy ref | Platform | Gateway deploy job, CI verify step | Public keys / policies, not private key material |
| **Gateway AWS API credentials** | FastAPI host | EC2/ECS **task role** (preferred) or IRSA-style | Cloud team | Gateway process only | Permissions: `ecs:RunTask`, `ecs:DescribeTasks`, `ecr:BatchGetImage` (if needed at gateway—prefer none), `logs:FilterLogEvents` or similar read-only ops per least privilege |
| **Fargate task execution role** | AWS ECS | IAM role (no secret blob) | Cloud team | Fargate agent | ECR pull, CloudWatch Logs write per AWS guidance |
| **Fargate task role (application)** | AWS ECS | IAM role | Cloud team | Code inside container | Start with **deny-by-default**; add only `logs:*` subset or artifact S3 prefix when required |
| **ECR / registry auth** | AWS | IAM (execution role) | N/A | Fargate | No `.docker/config` secrets in user space |
| **User session / API token** | Gateway / IdP | Gateway session store or IdP | App team | Next.js via cookie/header | Short TTL; scope to task APIs only |
| **LangGraph / LLM provider API keys** | Brain (gateway or sidecar same zone) | Secrets Manager | App / security | Gateway worker only | **Never** inject into execution container environment for v1 unless revisited by ADR |
| **Database credentials** (if introduced) | Gateway | Secrets Manager | App team | Gateway only | Not passed to Fargate |

## 2. IAM roles (named placeholders for Phase 2)

| IAM role name (placeholder) | Attached to | Purpose |
|----------------------------|-------------|---------|
| `fortress-gateway-task-role` | ECS task or EC2 instance running FastAPI | Invoke ECS, read task status, read logs, read verification artifacts |
| `fortress-fargate-execution-role` | Fargate task definition | ECR image pull, CloudWatch Logs for the task infrastructure |
| `fortress-fargate-task-role` | Fargate task definition | Minimal app permissions inside container |
| `fortress-ci-signing-role` | CI OIDC federated role | Build, sign with Cosign/KMS, push to ECR (Phase 1) |

## 3. Rotation and audit

- **KMS keys:** Annual review; immediate rotation on incident per AWS KMS procedures.
- **LLM / third-party keys:** Rotate on schedule and on personnel change; access logged in CloudTrail where applicable.
- **Break-glass:** Document separate process for human signing or policy override; forbid routine use.

## 4. References

- [container-supply-chain.md](../security/container-supply-chain.md)  
- [assumptions.md](./assumptions.md)  
