# Trino Service RPM CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Complete the adapter foundation first.

**Goal:** Add a reproducible Trino service RPM Build → clean Test → Release Candidate lifecycle.

**Architecture:** Package Trino with a custom service-RPM adapter, component-scoped JDK/runtime metadata, an exact allowlist, and a clean single-node smoke test that proves HTTP health and SQL execution. Reuse the lifecycle and fast-path contracts from the foundation plan.

**Tech Stack:** GitHub Actions, Python/YAML, Bash, Java, RPM/DNF, Docker/openEuler 22.03 LTS SP4, Trino.

**Spec:** `docs/superpowers/specs/2026-10-13-remaining-component-ci-design.md`

## Global Constraints

- Pin Trino stable version, immutable source identity, JDK, runtime packages, and all required dependencies after upstream verification.
- Do not modify the global JDK baseline.
- Build only configured runtime RPMs and reject undeclared artifacts.
- Clean smoke requires successful service startup, health endpoint, and a real SQL query.
- Exact-current matching repository artifacts take the fast path.

## Review Focus

- Upstream source/runtime is unsupported on target image: verify before adding enabled catalog entry in Task 1.
- RPM contains undeclared files or wrong service user/paths: assert package inventory and ownership in Task 2.
- Service opens health endpoint but cannot execute SQL: require query assertion in Task 3.
- Test silently uses stale repository RPM: match run/source/version provenance in Task 3.
- Dependency check accidentally compiles unrelated components: assert scoped dispatch in Task 4.

---

### Task 1: Lock Trino source, runtime, and RPM contract

**Files:**
- Create: `docs/trino-runtime-matrix.md`
- Modify: `ci/components.yaml`
- Modify: `scripts/ci/test-component-config.py`

**Interfaces:**
- `components.trino` uses `builder: custom`, `artifact_type: service-rpm`, exact `version`, immutable `source` + matching `source_identity`, `runtime_packages`, `build_task: trino-rpm`, `test_profile: trino-single-node-smoke`, exact `jdk` and `jdk_package`, and explicit `depends_on`.
- Matrix records official release/source URLs, ref/hash, JDK support evidence, runtime dependency list, RPM names, daemon command, and health/query probes.

- [ ] **Step 1: Add failing tests** `test_accepts_pinned_trino_custom_service`, `test_rejects_floating_trino_source`, `test_rejects_unpinned_trino_runtime`, and `test_rejects_empty_trino_package_allowlist`.
- [ ] **Step 2: Run `python3 scripts/ci/test-component-config.py`; confirm the new fixtures fail.**
- [ ] **Step 3: Verify current maintained Trino release and Java support using official release/runtime documentation; select immutable source and package contract.** If no supported build route exists, leave the component disabled and document evidence.
- [ ] **Step 4: Add matrix/catalog entry and rerun component-config tests.**
- [ ] **Step 5: Commit** `docs(ci): pin Trino service source and runtime`.

### Task 2: Build Trino runtime RPMs

**Files:**
- Create: `scripts/ci/build-trino-rpm-openeuler-container.sh`
- Modify: custom build dispatcher
- Test: `scripts/ci/test-custom-component-build.py`

**Interfaces:**
- Builder consumes validated catalog outputs and writes configured RPMs, package list, checksums, source identity, and build run provenance under the common artifacts/evidence root.
- Builder exits nonzero for source checksum mismatch, missing required payload, or any extra RPM outside the catalog allowlist.

- [ ] **Step 1: Add failing builder contract tests** `test_trino_builder_checks_source_identity`, `test_trino_builder_requires_complete_rpm_set`, `test_trino_builder_rejects_extra_rpm`, and `test_trino_manifest_records_jdk_and_run`.
- [ ] **Step 2: Run builder contract test module; confirm failures identify missing adapter behavior.**
- [ ] **Step 3: Implement the Trino package build adapter** using the pinned source and the package layout/runtime selected in Task 1.
- [ ] **Step 4: Run builder contract tests, `bash -n scripts/ci/build-trino-rpm-openeuler-container.sh`, and manifest checksum validation.**
- [ ] **Step 5: Commit** `feat(ci): build Trino service RPMs`.

### Task 3: Add clean install, health, and query smoke

**Files:**
- Create: `scripts/ci/test-trino-rpm-openeuler-container.sh`
- Modify: custom test dispatcher
- Test: `scripts/ci/test-custom-component-test.py`

**Interfaces:**
- Profile `trino-single-node-smoke` installs the exact tested RPMs, starts a single-node coordinator/worker, waits for its health endpoint, executes `SELECT 1` or equivalent through the CLI, and writes health/query/status plus source/build provenance evidence.

- [ ] **Step 1: Add failing test-profile tests** `test_trino_smoke_requires_health`, `test_trino_smoke_requires_sql_result`, `test_trino_smoke_installs_current_run_rpms`, and `test_trino_smoke_writes_provenance`.
- [ ] **Step 2: Run profile contract tests and confirm missing health/query evidence blocks PASS.**
- [ ] **Step 3: Implement bounded startup/SQL probes and cleanup** with logs retained on failure and no unbounded wait.
- [ ] **Step 4: Run profile contracts and `bash -n scripts/ci/test-trino-rpm-openeuler-container.sh`.**
- [ ] **Step 5: Commit** `test(ci): verify Trino startup and query in clean container`.

### Task 4: Wire scoped lifecycle and verify promotion

**Files:**
- Modify: `.github/workflows/build-components.yml`
- Modify: `.github/workflows/test-components.yml`
- Modify: `.github/workflows/release-components.yml`
- Modify: custom workflow contract test

- [ ] **Step 1: Add failing DAG tests** for Trino-only dispatch, required prerequisite gates, exact-current fast path, and failure blocking Release Candidate.
- [ ] **Step 2: Wire Trino through the reusable lifecycle and dispatch option.**
- [ ] **Step 3: Run component/config/fast-path/workflow tests and YAML validation.**
- [ ] **Step 4: Trigger Trino-targeted GitHub CI and verify actual Build, clean Test, Release Candidate, RPM PR contents, and successful repository merge.**
- [ ] **Step 5: Commit** `feat(ci): enable Trino RPM promotion lifecycle`.

## Completion Gate

- Trino is pinned and independently installable, service health plus SQL tests pass from same-run RPMs, the repo PR contains only configured payload, and current artifacts fast-pass without rebuilding.
