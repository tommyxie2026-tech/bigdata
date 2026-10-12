# Iceberg Integration RPM CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Complete the adapter foundation first.

**Goal:** Add pinned Iceberg connector RPMs and promote only compatibility tuples that pass real table write/read tests.

**Architecture:** Model Iceberg as an integration artifact, not a daemon. A pinned connector package declares engine/catalog/storage tuple and classpath; a clean runner installs same-run RPMs, creates a table, writes and reads it with declared engines, and emits tuple-bound evidence.

**Tech Stack:** GitHub Actions, Python/YAML, Bash, RPM/DNF, Iceberg, Flink 1.20.1, Spark 3.5.8, optional Trino, Hive Metastore/catalog, openEuler 22.03 LTS SP4.

**Spec:** `docs/superpowers/specs/2026-10-13-remaining-component-ci-design.md`

## Global Constraints

- Pin Iceberg and each engine/connector/catalog/storage tuple from official compatibility/release documentation.
- Use `artifact_type: integration-rpm`; never model table-format connectors as a daemon.
- Publish only exact allowlisted connector/runtime RPMs with same-run provenance and valid metadata.
- Compile/package success does not imply connector runtime compatibility.
- Exact tuple/source/artifact repository match may reuse the validated fast path.

## Review Focus

- Unsupported engine/connector version tuple: reject before build in Task 1.
- Duplicate/conflicting connector JAR selected by classpath: assert exact JAR loading in Task 2.
- Package installs but Flink cannot create/write/read a table: require table-operation evidence in Task 3.
- A claimed engine/catalog combination lacks its probe: release gate must fail in Task 3.
- Corrupt RPM/manifest/repodata is accepted as current: reuse foundation fast-path negative fixtures in Task 4.

---

### Task 1: Verify and pin compatibility matrix

**Files:**
- Create: `docs/iceberg-compatibility-matrix.md`
- Modify: `ci/components.yaml`
- Modify: `scripts/ci/test-component-config.py`

**Interfaces:**
- `components.iceberg` is a custom `integration-rpm` entry with immutable source, exact runtime RPM list, `test_profile: iceberg-cross-engine-smoke`, and `compatibility.engines/catalog/storage` entries.
- Each engine tuple records engine version, connector coordinate/version, expected RPM/JAR path, role (`write-read` or `read`), catalog, storage, and evidence field.

- [ ] **Step 1: Add failing tests** for a valid pinned tuple and rejection of version mismatch, missing engine role, duplicate connector coordinate, floating source, and omitted catalog/storage.
- [ ] **Step 2: Run config contract tests and verify each invalid tuple is rejected.**
- [ ] **Step 3: Inspect official Iceberg release compatibility docs and engine release matrices; select only confirmed tuples for Flink/Spark baseline.**
- [ ] **Step 4: Record pins and sources in the matrix and catalog; rerun config tests.**
- [ ] **Step 5: Commit** `docs(ci): pin Iceberg connector compatibility`.

### Task 2: Build allowlisted connector RPMs

**Files:**
- Create: `scripts/ci/build-iceberg-rpms-openeuler-container.sh`
- Test: `scripts/ci/test-integration-rpm-builder.py`
- Modify: custom build dispatcher

**Interfaces:**
- Builder consumes only the validated pin/matrix; emits configured RPMs, package inventory, SHA256SUMS, source identity, compatibility tuple, and build-run identity.
- Undeclared RPM/JAR, hash mismatch, missing package, or missing tuple metadata exits nonzero.

- [ ] **Step 1: Add failing builder tests** for missing JAR, unexpected RPM, wrong hash, and missing engine tuple.
- [ ] **Step 2: Run builder contract tests and verify each bad fixture fails.**
- [ ] **Step 3: Implement the RPM packaging adapter** for the pinned JARs and declared engine classpath layout.
- [ ] **Step 4: Run builder tests, `bash -n`, package inventory, and SHA256 verification.**
- [ ] **Step 5: Commit** `feat(ci): package Iceberg connectors as RPMs`.

### Task 3: Prove real cross-engine table operation

**Files:**
- Create: `scripts/ci/test-iceberg-rpms-openeuler-container.sh`
- Modify: custom test dispatcher
- Test: integration evidence contract tests

**Interfaces:**
- Profile `iceberg-cross-engine-smoke` installs current Build RPMs, uses declared catalog/storage, creates a uniquely named table, performs write/read with every `write-read` engine and read with every `read` engine, verifies row values, cleans temporary table, and writes per-engine evidence with provenance.

- [ ] **Step 1: Add failing evidence tests** for missing Flink write/read, missing Spark read, mismatched Trino read when configured, catalog visibility failure, and wrong build-run provenance.
- [ ] **Step 2: Run the evidence tests; ensure any absent/failing operation blocks tested-RPM output.**
- [ ] **Step 3: Implement bounded engine/table probes** using only pinned engine and connector artifacts.
- [ ] **Step 4: Run integration profile contract tests and `bash -n` for the clean runner.**
- [ ] **Step 5: Commit** `test(ci): verify Iceberg table interoperability`.

### Task 4: Wire component DAG, fast path, and promotion

**Files:**
- Modify: `.github/workflows/build-components.yml`
- Modify: `.github/workflows/test-components.yml`
- Modify: `.github/workflows/release-components.yml`
- Modify: `scripts/ci/test-component-repo-fast-path.py`

- [ ] **Step 1: Add tests** for exact compatibility-tuple fast pass, changed tuple cache miss, dependency gates, scoped Iceberg dispatch, and failed-operation Release Candidate block.
- [ ] **Step 2: Wire Iceberg after its declared Flink/Spark/catalog prerequisites through the reusable lifecycle.**
- [ ] **Step 3: Run all config, builder, evidence, fast-path, dependency, workflow, Bash syntax, and YAML tests.**
- [ ] **Step 4: Run targeted Iceberg CI and inspect the repository PR for exact RPM allowlist, SHA256SUMS, provenance, and valid DNF metadata.**
- [ ] **Step 5: Merge promotion only after required checks; confirm clean install/load verification from merged repository.**

## Completion Gate

- Each advertised Iceberg tuple passes actual connector load and its required table operations, and repository reuse validates the full tuple.
