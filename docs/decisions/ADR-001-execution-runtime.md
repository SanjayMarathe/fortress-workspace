# ADR-001: Golden execution runtime (Wolfi / Melange)

**Status:** Accepted (Phase 0 draft)  
**Date:** 2026-04-22  
**Deciders:** Sanjay Marathe (Owner)

## Context

Fortress needs a single **golden** execution stack for the first vertical slice: minimal attack surface, compatibility with Python agent tooling (LangGraph on the Brain plane), and a path to Melange-built APKs and Cosign-signed OCI images.

## Decision

1. **Primary execution language in the container:** **Python 3** (specific minor version pinned at build time in Melange, not “floating latest” in production tags without CI).

2. **Orchestration (LangGraph):** Runs on the **Brain plane** (FastAPI host), **not** inside the Fargate execution container for v1. The execution image runs a **small runner** that executes bounded work (e.g. run tests, write files to ephemeral task storage, return results).

3. **Base OS:** **Wolfi**-derived image built with **Melange** recipes maintained in-repo (Phase 1).

4. **In-container package policy (v1):**
   - **Interpreter:** Python from Wolfi packages built via Melange.
   - **Dependencies:** Prefer **declared wheels** baked into the image at build time (Melange/APK layer). **No arbitrary `pip install` at runtime** from the public internet in production tasks unless a future ADR explicitly allows a curated mirror.
   - **Compilation in-container:** **Not allowed** in production v1 (no `gcc` toolchain in the execution image). Native extensions must be prebuilt into the image in CI/Melange.
   - **Shell:** **No interactive shell** (`sh`/`bash`) in the **production** execution image. If a debugging image is required pre-GA, it must be a **separate image name/tag family** that is **not** admitted by production Cosign policy.

5. **Acceptance criteria (carried to Phase 1):**
   - Image size tracked vs a baseline “standard Python” image; target remains **~90% reduction** as a product metric, not a gate for every interim build.
   - **Critical/High CVE policy:** Zero Critical/High at merge time per Grype policy (Phase 1 automation); exceptions require security exception record.

## Consequences

### Positive

- Aligns with LangGraph/Python ecosystem while keeping execution images small and auditable.
- Disabling runtime `pip` and in-container compilers reduces drive-by supply-chain risk from task code.

### Negative

- Slower iteration when new Python deps are needed (requires image rebuild).
- Debugging is harder without a shell; rely on structured logging and reproducible local Wolfi builds for dev.

## Alternatives considered

- **Node-only execution:** Rejected for v1 due to LangGraph/Python-first agent plan.
- **Shell + compiler in production image:** Rejected for v1 CVE and size posture; optional debug image family reserved for non-prod.

## Footnote: Wolfi transitive packages (shell)

Wolfi APKs such as `python-3.12-base` or `wolfi-base` may pull a minimal userland (for example **busybox**) as a transitive dependency. That is **not** the same as shipping an interactive shell as `ENTRYPOINT`. Phase 1 records the **actual** Syft/Grype results for each build. If a shell binary is present only as dependency surface, document it in the SBOM review; do not silently weaken the “no shell in prod image” goal without an ADR update.

## References

- [trust-boundaries.md](../architecture/trust-boundaries.md)  
- [container-supply-chain.md](../security/container-supply-chain.md)  
- [Phase 1 runbook](../build/phase1-runbook.md)  
