# Remaining Component CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement these plans task-by-task. Complete the shared adapter contract first, then implement each component plan independently and honor its gate.

**Goal:** Add idempotent Build → clean Test → Release Candidate pipelines for Trino, Hue, Iceberg, Hudi, and Paimon without rebuilding current repository artifacts.

**Architecture:** Extend the current reusable component lifecycle through explicit service-RPM and integration-RPM adapters, immutable source/runtime metadata, compatibility-aware evidence, and component-scoped DAG dispatch. Split execution into a shared foundation followed by independent Trino, Hue, Iceberg, Hudi, and Paimon plans; Hue begins with a feasibility gate, and Hudi/Paimon remain Batch 2 until Batch 1 is accepted.

**Tech Stack:** GitHub Actions, Python/YAML contract validation, Bash, Docker with openEuler 22.03 LTS SP4, RPM/DNF, createrepo_c, Java/Python runtimes selected per component, and upstream project release metadata.

**Spec:** `docs/superpowers/specs/2026-10-13-remaining-component-ci-design.md`

## Global Constraints

- Preserve all existing component jobs and exact-current repository fast paths.
- Use exact version and immutable source SHA/ref for every new component; no floating refs or `latest`.
- Keep component JDK/Python requirements scoped to that component; do not change the global legacy toolchain.
- Fast-pass only with exact package/version/source/compatibility identity, checksums, manifest, valid repository metadata, and clean-install evidence.
- Test the same-run artifacts; Release Candidate requires successful Build and Test evidence for that exact artifact set.
- Failed, cancelled, missing, stale, corrupt, or incompatible evidence cannot pass a gate.
- Service RPMs test daemon startup/health and a real probe; integration RPMs test connector loading and actual table operations.
- Component dispatch includes only the requested component and declared dependencies; unrelated components stay on valid fast paths.
- Do not publish an aggregate repository tarball or product release.

## Review Focus

- Existing six-component and Kafka/Flink dispatch behavior regresses: protect with current workflow regression tests in Foundation Task 1.
- A false fast-pass accepts stale/missing/corrupt package or compatibility evidence: exercise exact match and negative fixtures in Foundation Task 2.
- A skipped/cancelled stage is treated as green: assert stage gate outputs require explicit success evidence in Foundation Task 2.
- A new builder ignores the component-specific runtime or packages undeclared RPMs: reject with adapter contract tests in each component plan.
- A connector compiles but cannot load or operate at runtime: require actual write/read smoke evidence in Iceberg/Hudi/Paimon plans.

## Execution Order

1. `2026-10-13-component-adapter-foundation.md` — extend generic metadata/build/test dispatch safely.
2. `2026-10-13-trino-service-ci.md` — Batch 1 query service.
3. `2026-10-13-hue-service-ci.md` — Batch 1 feasibility first, then service pipeline only if feasible.
4. `2026-10-13-iceberg-integration-ci.md` — Batch 1 table-format connector.
5. `2026-10-13-hudi-integration-ci.md` — Batch 2; start after Iceberg completion gate.
6. `2026-10-13-paimon-integration-ci.md` — Batch 2; start after Iceberg completion gate.

For each component, first check the existing repository fast path and reuse same-tree successful evidence where the lifecycle contract permits. Run only targeted CI for that component and its declared prerequisites. Do not merge a component PR until its latest-head checks and required Build/Test jobs are successful; PR-stage Release Candidate may be skipped by design. After merge, follow main Release Candidate and RPM promotion PR through merge before marking that component delivered.

## Batch Gates

- **Batch 1 complete:** Trino and Iceberg delivered; Hue either delivered or has a concrete feasibility blocker recorded with evidence. Batch 2 may then begin.
- **Batch 2 complete:** Hudi and Paimon each independently pass compatibility, clean install, real table operation, fast-path, and RPM repository promotion checks.
- **Overall complete:** all feasible approved components are promoted, blocked components have evidence-backed dispositions, and existing components remain unchanged.
