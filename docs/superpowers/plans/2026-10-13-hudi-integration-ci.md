# Hudi Integration RPM CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Start only after the shared foundation and Iceberg completion gates pass.

**Goal:** Add Hudi as an optional integration-RPM profile with independently validated Flink/Spark table operations.

**Architecture:** Reuse the foundation's integration artifact and provenance contract. Lock Hudi connector tuples against the actual repository Flink/Spark/catalog versions; package only declared runtime artifacts and run same-build clean tests. Hudi remains isolated from Iceberg defaults and dispatch.

**Tech Stack:** GitHub Actions, Python/YAML, Bash, RPM/DNF, Apache Hudi, Flink 1.20.1, Spark 3.5.8, configured catalog/storage, openEuler 22.03 LTS SP4.

**Spec:** `docs/superpowers/specs/2026-10-13-remaining-component-ci-design.md`

## Global Constraints

- Hudi is Batch 2 and optional; it must not replace or alter Iceberg behavior.
- Pin every source, connector, engine, catalog, and storage tuple.
- Unsupported tuples are rejected before Build; do not infer runtime support from compilation.
- Require actual table write/read evidence before Release Candidate.
- Exact-current artifacts reuse the fast path only when provenance and tuple both match.

## Review Focus

- Connector supports Spark but not configured Flink version: Task 1 rejects unsupported tuple.
- Missing Hudi RPM/JAR erroneously fast-passes: Task 2 tests incomplete repo.
- Build succeeds but table write/read fails: Task 3 blocks tested artifact.
- Adding Hudi changes Iceberg default route: Task 4 regression test.
- Failure incorrectly blocks unrelated components: Task 4 DAG isolation test.

---

### Task 1: Define optional Hudi compatibility profile

**Files:**
- Create: `docs/hudi-compatibility-matrix.md`
- Modify: `ci/components.yaml`
- Modify: `scripts/ci/test-component-config.py`

**Interfaces:**
- `components.hudi` is a custom `integration-rpm` with exact source/version, runtime packages, `test_profile: hudi-cross-engine-smoke`, and tuple-specific engine/catalog/storage mapping.
- Matrix states which engine performs write/read and which perform reads, with exact version and package/classpath location.

- [ ] **Step 1: Add failing tests** for optional profile, pinned source, supported tuple, unsupported tuple, and exact package allowlist.
- [ ] **Step 2: Run config tests and confirm invalid Hudi records fail.**
- [ ] **Step 3: Verify official Hudi release compatibility against Flink/Spark baseline; pin only supported tuple(s), otherwise document blocked profile and do not enable it.**
- [ ] **Step 4: Add matrix/catalog metadata and rerun config validation.**
- [ ] **Step 5: Commit** `docs(ci): define optional Hudi compatibility profile`.

### Task 2: Build Hudi connector RPMs

**Files:**
- Create: `scripts/ci/build-hudi-rpms-openeuler-container.sh`
- Test: `scripts/ci/test-integration-rpm-builder.py`
- Modify: custom build dispatcher

- [ ] **Step 1: Add failing tests** for missing Hudi connector, checksum mismatch, unallowlisted package, and absent tuple in manifest.
- [ ] **Step 2: Run builder tests and confirm invalid artifacts fail.**
- [ ] **Step 3: Package the exact artifacts from the pinned compatibility matrix with tuple-bound manifest/checksums.**
- [ ] **Step 4: Run builder contracts, shell syntax, inventory, and checksum validation.**
- [ ] **Step 5: Commit** `feat(ci): package Hudi integration RPMs`.

### Task 3: Test Hudi table write/read

**Files:**
- Create: `scripts/ci/test-hudi-rpms-openeuler-container.sh`
- Modify: custom test dispatcher
- Test: integration evidence contract tests

**Interfaces:**
- Profile `hudi-cross-engine-smoke` installs same-run RPMs, creates a disposable catalog table, performs a write/read operation in each matrix-required engine, validates expected rows, and emits engine-specific evidence with source/build/run/tuple identity.

- [ ] **Step 1: Add failing tests** for absent write/read, invalid row result, wrong artifact run ID, and catalog mismatch.
- [ ] **Step 2: Run tests and confirm any failed/missing evidence blocks Release Candidate.**
- [ ] **Step 3: Implement bounded table smoke and cleanup** for only the pinned engines in the matrix.
- [ ] **Step 4: Run evidence tests and `bash -n` for the Hudi runner.**
- [ ] **Step 5: Commit** `test(ci): verify Hudi table operations`.

### Task 4: Wire isolated lifecycle and promote

**Files:**
- Modify: `.github/workflows/build-components.yml`
- Modify: `.github/workflows/test-components.yml`
- Modify: `.github/workflows/release-components.yml`
- Modify: `scripts/ci/test-component-repo-fast-path.py`
- Test: custom workflow contract suite

- [ ] **Step 1: Add DAG tests** for Hudi-only dispatch, declared dependencies, failure isolation, exact tuple fast pass, and Iceberg route unchanged.
- [ ] **Step 2: Wire Hudi to reusable lifecycle as a Batch 2 opt-in profile.**
- [ ] **Step 3: Run Hudi, config, fast-path, workflow, YAML, shell, and existing component regression suites.**
- [ ] **Step 4: Run Hudi targeted GitHub Build → Test → Release Candidate and confirm repository PR contents.**
- [ ] **Step 5: Commit** `feat(ci): enable Hudi lifecycle and promotion`.

## Completion Gate

- At least one declared Hudi engine profile passes real table operations and clean repository installation; Hudi remains independently selectable.
