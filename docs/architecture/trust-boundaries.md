# Fortress: Trust Boundaries and Threat Assumptions

**Status:** Draft (Phase 0)  
**Owner:** Sanjay Marathe

This document is the canonical trust model for Fortress v1. Downstream design (Melange images, FastAPI gateway, Fargate, IAM) must not contradict it.

## 1. Components and trust zones

| Zone | Components | Trust level |
|------|----------------|-------------|
| **User** | Browser, human operator | Untrusted input; authenticated where required |
| **Presentation** | Next.js application | Trusted to render UI only; holds no long-lived registry or cloud credentials |
| **Brain (control)** | FastAPI gateway, future queue/DB | Trusted orchestrator; **must not** execute arbitrary user code on this plane |
| **Cloud control** | AWS APIs used to start/stop tasks, read logs, pull images by digest | Trusted AWS backbone; access via least-privilege IAM from Brain only |
| **Registry** | Amazon ECR (private) | Source of execution images; **only** signed, policy-approved digests are runnable |
| **Execution** | AWS Fargate tasks running Wolfi-derived minimal images | **Highest isolation**; assumed hostile from Brain’s perspective (treat output as untrusted until validated) |
| **Signing / policy** | Cosign, KMS, verification policy | Trusted to bind identity and integrity to image digests |
| **Observability** | Log/metric/trace sinks | Trusted for operations; must not become a covert channel for secrets (redaction, structured logging) |

## 2. Brain vs execution vs registry

### 2.1 Brain (FastAPI gateway plane)

- **Responsibilities:** Authenticate users, accept tasks, choose image digest (from allowlist), call AWS to run Fargate tasks, stream status to the client, collect results and provenance metadata (SBOM pointer, signature verification outcome).
- **Does not:** Run user-supplied code as the gateway process. Does not hold SSH/RDP sessions into Fargate tasks.
- **LangGraph (v1 assumption):** Orchestration runs **on the Brain plane** (same trust zone as FastAPI), not inside the Fargate execution container. The execution container runs a **thin agent runner** (e.g. Python entrypoint) that receives bounded instructions or artifacts from the gateway over approved channels (see [data-flows.md](./data-flows.md)).

### 2.2 Execution (Fargate)

- **Responsibilities:** Run the minimal runtime, execute generated/tested code **inside** the isolated task, emit logs and exit artifacts.
- **Trust:** Compromised execution must not grant control of the Brain or broad AWS scope. Task role is **minimal** (e.g. CloudWatch Logs, optional narrow S3 prefix for artifacts—if added later).

### 2.3 Registry (ECR)

- **Responsibilities:** Store immutable image layers; serve pulls initiated by Fargate infrastructure (not by arbitrary code paths in user programs unless explicitly designed and blocked otherwise).
- **Admission:** Only images that satisfy [container supply chain policy](../security/container-supply-chain.md) are referenced by digest in task definitions.

## 3. Per-boundary summary

Detailed protocols and data classes are in [data-flows.md](./data-flows.md) and [secrets-identity.md](./secrets-identity.md).

| Boundary | From → To | AuthN | Notes |
|----------|-----------|--------|--------|
| User → Next.js | Browser → App | Session/cookie or OIDC (TBD implementation) | No cloud secrets in browser |
| Next.js → Gateway | App → FastAPI | HTTPS; bearer or session | Prompts and task payloads |
| Gateway → AWS | FastAPI → ECS/ECR/etc. | IAM (task/instance role or IRSA-style for gateway host) | No user code on this credential |
| AWS → ECR | Fargate → ECR | Task execution role | Image pull by **digest** only |
| Gateway ↔ Execution | Logical | Indirect via AWS APIs and task design | No interactive shell from gateway to task in v1 |

## 4. Threat assumptions

### 4.1 In scope for design (mitigate or detect)

- **Prompt injection / malicious task intent:** User tries to exfiltrate secrets or abuse cloud APIs. Mitigation: least-privilege IAM for gateway and task; no broad secrets in execution; output validation policies as product evolves.
- **Supply-chain substitution:** Attacker pushes unsigned or wrong image. Mitigation: Cosign verify on digest; private ECR; CI-only pushes.
- **Compromised execution task:** Attacker escapes to “neighbor” access—bounded by Fargate isolation; lateral movement limited by IAM and network controls (see assumptions for network posture).
- **Compromised gateway (“Brain”):** Phase 0 does not claim cryptographic prevention of a fully compromised gateway. **In scope:** detection and blast-radius limits—audit logs, short-lived credentials, no single key that can rewrite registry policy and production IAM without break-glass.

### 4.2 Explicit non-goals for v1

- **Gateway runs user code:** Out of scope; forbidden by architecture.
- **SSH from operators or gateway into Fargate tasks:** Out of scope for v1 (use logs and replayable artifacts instead).
- **User-uploaded arbitrary container images:** Out of scope; users do not supply image URIs outside the hardened catalog.
- **Mathematical “zero CVE forever”:** Out of scope. Operational meaning is **policy at build time + continuous scanning + rebuild** (see supply chain doc).

### 4.3 “Zero-CVE” wording (risk register)

Use externally: **“Zero Critical/High CVEs at build time per policy, with continuous monitoring and mandatory rebuild when policy is violated.”** Avoid implying proof against all future vulnerabilities.

## 5. Related documents

- [data-flows.md](./data-flows.md) — End-to-end flows and per-hop data classification  
- [secrets-identity.md](./secrets-identity.md) — Secrets and IAM matrix  
- [assumptions.md](./assumptions.md) — AWS tenancy, regions, air-gap meaning  
- [../decisions/ADR-001-execution-runtime.md](../decisions/ADR-001-execution-runtime.md) — Golden runtime choice  
- [../security/container-supply-chain.md](../security/container-supply-chain.md) — ECR, Cosign, SBOM admission  

## 6. Definition of alignment (Phase 0)

Stakeholders agree: (1) LangGraph lives on the **Brain** plane for v1, (2) user code runs **only** in Fargate execution, (3) an image is runnable only after **digest + signature + policy** steps defined in security docs.
