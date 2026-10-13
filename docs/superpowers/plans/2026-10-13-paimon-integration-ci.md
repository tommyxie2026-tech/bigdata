# Paimon Integration RPM CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Start only after the shared foundation and Iceberg completion gates pass.

**Goal:** Add Apache Paimon as an independently selectable integration-RPM profile with version-pinned engine/catalog table tests.

**Architecture:** Reuse the integration artifact contract from the foundation. Add a custom Paimon connector package and compatibility matrix; run same-run RPMs in a clean environment and validate actual table operations for each explicitly supported engine tuple. Do not treat Paimon as a daemon or fold it into Iceberg.

**Tech Stack:** GitHub Actions, Python/YAML, Bash, RPM/DNF, Apache Paimon, Flink 1.20.1 and any separately verified Spark/Trino support, catalog/storage pinned in the matrix, openEuler 22.03 LTS SP4.

**Spec:** `docs/superpowers/specs/2026-10-13-remaining-component-ci-design.md`

## Global Constraints

- Paimon is Batch 2 and independent from Hudi.
- Pin Paimon, engine, catalog, storage, connector coordinates, and immutable source identity.
- Advertise only compatibility combinations documented upstream and proven by clean runtime tests.
- Release Candidate requires real table operation evidence and exact artifact provenance.
- Use the repository fast path only for a complete, checksum-valid exact tuple.

## Review Focus

- Unsupported engine/catalog combination: Task 1 marks it unsupported and rejects it.
- Connector JAR collision selects an undeclared version: Task 2 checks actual loaded coordinates.
- Table write succeeds but read returns incorrect data: Task 3 validates exact rows.
- Paimon artifact missing from repo but another table-format package exists: Task 4 must cache-miss.
- Paimon workflow runs Hudi or rebuilds healthy dependencies: Task 4 asserts scoped DAG behavior.

---

### Task 1: Lock Paimon version and compatibility matrix

**Files:**
- Create: `docs/paimon-compatibility-matrix.md`
- Modify: `ci/components.yaml`
- Modify: `scripts/ci/test-component-config.py`

**Interfaces:**
- `components.paimon` is custom `integration-rpm`, with exact source/version, allowlisted runtime packages, `test_profile: paimon-cross-engine-smoke`, and compatibility engine/catalog/storage tuple entries.
- Each tuple records operation roles, exact coordinates, classpath path, expected runtime identity, and evidence names.

- [ ] **Step 1: Add failing tests** for valid pinned tuple, unsupported engine version, missing catalog/storage, floating source, and incomplete package allowlist.
- [ ] **Step 2: Run config tests and confirm invalid tuples are rejected.**
- [ ] **Step 3: Verify official Paimon release/compatibility metadata; pin only supported tuples and record immutable source identity.**
- [ ] **Step 4: Update matrix and catalog and rerun config validation.**
- [ ] **Step 5: Commit** `docs(ci): pin Paimon integration compatibility`.

### Task 2: Build Paimon connector RPMs

**Files:**
- Create: `scripts/ci/build-paimon-rpms-openeuler-container.sh`
- Test: `scripts/ci/test-integration-rpm-builder.py`
- Modify: custom build dispatcher

- [ ] **Step 1: Add failing builder tests** for missing connector, unexpected RPM, hash mismatch, and missing tuple provenance.
- [ ] **Step 2: Run builder tests and verify invalid artifacts fail closed.**
- [ ] **Step 3: Implement package adapter** for the matrix's exact RPM/JAR allowlist and selected classpath layout.
- [ ] **Step 4: Run builder contract tests, Bash syntax, RPM inventory, and checksum checks.**
- [ ] **Step 5: Commit** `feat(ci): package Paimon integration RPMs`.

### Task 3: Verify Paimon table operations

**Files:**
- Create: `scripts/ci/test-paimon-rpms-openeuler-container.sh`
- Modify: custom test dispatcher
- Test: integration evidence contract tests

**Interfaces:**
- Profile `paimon-cross-engine-smoke` installs same-run RPMs, creates a uniquely named test table, writes known records and verifies reads for every matrix-declared operation role, then emits tuple/run-bound evidence and cleans up.

- [ ] **Step 1: Add failing evidence tests** for missing engine role, wrong loaded connector coordinates, wrong output rows, provenance mismatch, and failed cleanup.
- [ ] **Step 2: Run evidence tests and verify any mismatch blocks tested-artifact output.**
- [ ] **Step 3: Implement bounded create/write/read probes for only pinned combinations.**
- [ ] **Step 4: Run integration evidence tests and `bash -n` for Paimon runner.**
- [ ] **Step 5: Commit** `test(ci): verify Paimon table operations`.

### Task 4: Wire isolated workflow, fast path, and promotion

**Files:**
- Modify: `.github/workflows/build-components.yml`
- Modify: `.github/workflows/test-components.yml`
- Modify: `.github/workflows/release-components.yml`
- Modify: `scripts/ci/test-component-repo-fast-path.py`
- Test: custom workflow contract suite

- [ ] **Step 1: Add tests** for Paimon-only dispatch, no Hudi execution, declared prerequisite gates, exact tuple fast pass, and missing artifact cache miss.
- [ ] **Step 2: Wire Paimon to reusable lifecycle with the selected prerequisites only.**
- [ ] **Step 3: Run Paimon/config/evidence/fast-path/DAG/YAML/shell and existing lifecycle tests.**
- [ ] **Step 4: Run targeted Paimon GitHub Build → Test → Release Candidate; inspect repository promotion PR allowlist and metadata.**
- [ ] **Step 5: Commit** `feat(ci): enable Paimon lifecycle and promotion`.

## Completion Gate

- Every advertised Paimon combination passes real table operation tests with exact connector provenance, and repository fast-path validation matches the entire tuple.
