# Hue Service RPM CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Do not build the service until the feasibility gate is documented and passes.

**Goal:** Determine whether Hue can be reproducibly packaged and smoke-tested as a service RPM on the target openEuler image; add its lifecycle only if evidence supports it.

**Architecture:** Begin with a fail-closed feasibility report covering maintained upstream source, Python/native dependencies, OS support, packaging route, and a real HiveServer2 or Trino connection. If feasible, implement a custom service adapter and disposable-metadata clean test. If infeasible, record the exact blocker and stop this component without adding a green placeholder.

**Tech Stack:** Official Hue release/source docs, Python/build tooling supported by openEuler 22.03 LTS SP4, RPM/DNF, Docker, GitHub Actions, HiveServer2/Trino protocol probe.

**Spec:** `docs/superpowers/specs/2026-10-13-remaining-component-ci-design.md`

## Global Constraints

- No compile attempt before source/runtime/packaging feasibility is documented.
- Use immutable source and exact runtime/package allowlist.
- Disposable metadata must not depend on an external production database.
- Hue health alone is insufficient: the smoke must connect to an actual configured HiveServer2 or Trino endpoint.
- Fast path must verify the full Hue RPM/provenance and installability.

## Review Focus

- Upstream is unmaintained or source cannot be pinned: Task 1 records evidence and halts.
- Python/native dependency unavailable on target OS: Task 1 records a concrete blocker before build.
- UI/HTTP health succeeds while query backend is disconnected: Task 3 requires protocol-level endpoint connection.
- Disposable metadata accidentally persists: Task 3 asserts temp-only state and teardown.
- Unsupported Hue source is represented as a passing/skipped build: Task 4 requires explicit blocked status, not pass.

---

### Task 1: Produce Hue feasibility gate

**Files:**
- Create: `docs/hue-feasibility.md`
- Reference: official Hue release/source and deployment documentation; target image package availability

**Interfaces:**
- Feasibility report records source URL, release/ref/hash candidate, maintenance evidence, target Python/JDK/native libraries, RPM ownership/layout, clean install path, metadata backend, backend-query probe, and a `feasible|blocked` decision with evidence.

- [ ] **Step 1: Inspect maintained upstream releases and documented runtimes from primary Hue sources.**
- [ ] **Step 2: Check target openEuler package availability/buildability for Python and native dependencies without downloading large artifacts.**
- [ ] **Step 3: Define the custom RPM file/service contract and a disposable metadata/query backend approach; list unsupported assumptions.**
- [ ] **Step 4: Record feasibility and concrete evidence in `docs/hue-feasibility.md`.** If blocked, stop this plan after reporting the evidence-backed blocker.
- [ ] **Step 5: Commit** `docs(ci): record Hue packaging feasibility`.

### Task 2: Pin Hue source and add catalog contract (feasible path only)

**Files:**
- Modify: `ci/components.yaml`
- Modify: `scripts/ci/test-component-config.py`
- Modify: `docs/hue-runtime-matrix.md`

**Interfaces:**
- `components.hue` is `builder: custom`, `artifact_type: service-rpm`, with exact version/source identity, runtime packages, Python/runtime metadata, `build_task: hue-rpm`, `test_profile: hue-single-node-smoke`, and declared service dependencies.

- [ ] **Step 1: Add failing config tests** for pinned Hue archive/git input, required runtime metadata, exact allowlist, and rejection of floating source refs.
- [ ] **Step 2: Run config tests; confirm invalid Hue records fail.**
- [ ] **Step 3: Add the immutable source, runtime matrix, and component entry supported by Task 1 evidence.**
- [ ] **Step 4: Run config validator/tests and commit** `feat(ci): pin Hue service build contract`.

### Task 3: Build and clean-test Hue (feasible path only)

**Files:**
- Create: `scripts/ci/build-hue-rpm-openeuler-container.sh`
- Create: `scripts/ci/test-hue-rpm-openeuler-container.sh`
- Modify: custom build/test dispatcher and `.github/workflows/build-components.yml`
- Test: custom builder/profile contract tests

**Interfaces:**
- `hue-single-node-smoke` installs same-run RPMs, starts Hue with disposable metadata, checks bounded HTTP readiness, makes a real connection/query handshake against the configured HiveServer2 or Trino endpoint, and emits explicit evidence fields plus provenance.

- [ ] **Step 1: Add failing contract tests** for exact RPM allowlist, start/readiness, backend handshake, disposable metadata, provenance, and teardown on failure.
- [ ] **Step 2: Run tests and confirm missing backend evidence blocks PASS.**
- [ ] **Step 3: Implement builder and bounded smoke** using the pinned source/runtime; fail on unselected payloads or missing endpoint support.
- [ ] **Step 4: Run contract tests, `bash -n` on both Hue scripts, and package/checksum validation.**
- [ ] **Step 5: Commit** `feat(ci): build and smoke-test Hue service RPM`.

### Task 4: Wire scoped lifecycle and promote

**Files:**
- Modify: `.github/workflows/build-components.yml`
- Modify: `.github/workflows/test-components.yml`
- Modify: `.github/workflows/release-components.yml`
- Test: custom component workflow contracts

- [ ] **Step 1: Add failing tests** for Hue-only dispatch, declared Hive/Trino gate behavior, infeasible component not being reported as pass, and fast-path no-op.
- [ ] **Step 2: Wire the feasible Hue profile to the common lifecycle.**
- [ ] **Step 3: Run catalog, fast-path, workflow, shell, and YAML validation suites.**
- [ ] **Step 4: Run Hue-targeted GitHub CI and verify Build/Test/Release Candidate and the repository promotion PR.**
- [ ] **Step 5: Commit** `feat(ci): enable Hue RPM release candidate`.

## Completion Gate

- Either Hue is promoted after a real startup/health/backend test, or the feasibility document states a reproducible blocker and Hue remains explicitly not delivered.
