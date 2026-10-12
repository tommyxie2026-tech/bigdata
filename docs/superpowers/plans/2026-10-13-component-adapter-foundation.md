# Component Adapter Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. This foundation must pass before component adapters are added.

**Goal:** Extend the existing idempotent component lifecycle so custom service RPM and integration RPM components can be built, tested, and promoted using explicit contracts.

**Architecture:** Keep `.github/workflows/component-lifecycle.yml` as the stage owner and add explicit builder/test dispatch behind catalog metadata. Extend validation and fast-path identity to include immutable source and compatibility data. Preserve existing Bigtop workflows and behavior.

**Tech Stack:** Python 3, PyYAML, Bash, GitHub Actions YAML, Docker/openEuler 22.03 LTS SP4, RPM manifests and DNF metadata.

**Spec:** `docs/superpowers/specs/2026-10-13-remaining-component-ci-design.md`

## Global Constraints

- Do not alter existing component source pins, package allowlists, or toolchains.
- Custom Git sources require full immutable commit SHA; archives require SHA-256.
- Integration artifact identity includes engine, connector, catalog, and storage tuple.
- Exact-current fast path is a true no-build/no-test/no-release path only after every repository and evidence check succeeds.
- A missing/failed/skipped/cancelled required stage never yields a successful promotion gate.

## Review Focus

- Unknown builder/test profile fails closed: cover in Task 1.
- Floating custom source or incomplete runtime metadata is rejected: cover in Task 1.
- Stale compatibility metadata reuses an obsolete integration RPM: cover in Task 2.
- Fast-path success skips Build/Test/Release only with complete evidence: cover in Task 2.
- Component-scoped dispatch accidentally runs unrelated jobs: cover in Task 3.

---

### Task 1: Harden catalog and adapter contracts

**Files:**
- Modify: `scripts/ci/validate-components.py`
- Modify: `scripts/ci/test-component-config.py`
- Modify: `scripts/ci/build-one-component.yml`
- Modify: `scripts/ci/test-components.yml`
- Test: existing component catalog and workflow contract suites

**Interfaces:**
- Catalog keeps `builder: bigtop|custom`, `artifact_type: service-rpm|integration-rpm`, exact `runtime_packages`, `build_task`, `test_profile`, component `jdk`/package, immutable `source_identity`, and optional `compatibility` mapping for integrations.
- Build dispatcher calls `build-bigtop-component.sh` for `builder=bigtop` and a named custom builder selected by a validated `build_task` for `builder=custom`.
- Test dispatcher routes validated `test_profile` to a named test script; no arbitrary shell string execution from catalog values.

- [ ] **Step 1: Add failing catalog tests** for missing source identity, floating custom refs, unpinned archives, unsupported runtime, duplicate/empty package allowlists, invalid compatibility engines, and unknown profile tokens.
- [ ] **Step 2: Run `python3 scripts/ci/test-component-config.py`; verify each new invalid fixture fails validation.**
- [ ] **Step 3: Implement the narrow validator changes** while leaving the legacy six entries and Kafka/Flink records valid.
- [ ] **Step 4: Add failing dispatcher tests** proving Bigtop components use the existing builder, custom service/integration components reach their named adapter, and unrecognized adapter/profile names fail closed.
- [ ] **Step 5: Implement build/test dispatch** using explicit case statements and validated config outputs; do not `eval` catalog values.
- [ ] **Step 6: Run config, streaming component, lifecycle workflow, and shell syntax tests; verify all existing profiles still route identically.**
- [ ] **Step 7: Commit** `feat(ci): add explicit custom component adapters`.

### Task 2: Bind compatibility/provenance to repository fast path

**Files:**
- Modify: `scripts/ci/check-component-repo-fast-path.py`
- Modify: `scripts/ci/test-component-repo-fast-path.py`
- Modify: `scripts/ci/resolve-component-dependencies.py`
- Modify: `scripts/ci/stage-tested-rpms.sh`
- Modify: `.github/workflows/component-lifecycle.yml`

**Interfaces:**
- `evidence.md`/manifest carries component id, exact version, source identity, artifact type, allow-listed filenames/checksums, build run/source, test run/source, and compatibility tuple when applicable.
- Fast-path validation returns `status=PASS` only for exact manifest equality, valid SHA256SUMS, valid repo metadata, and a clean DNF install/load probe; otherwise it returns a cache miss and normal lifecycle proceeds.
- Stage gate output remains explicit boolean `stage_passed`; only validated repo reuse or successful Build+Test can set true.

- [ ] **Step 1: Add fast-path fixture tests** for exact service match, changed source identity, changed compatibility tuple, missing RPM, extra RPM, bad checksum, incomplete manifest, invalid repo metadata, and failed clean install.
- [ ] **Step 2: Run `python3 scripts/ci/test-component-repo-fast-path.py`; verify only exact complete fixtures pass.**
- [ ] **Step 3: Extend manifest comparison** to include source/artifact/compatibility identity and exact runtime artifact allowlist.
- [ ] **Step 4: Add lifecycle tests** proving repository fast-pass marks the stage reusable and avoids Build/Test/Release, while miss/corruption enters normal Build/Test and failed/cancelled evidence blocks Release Candidate.
- [ ] **Step 5: Run `python3 scripts/ci/test-component-repo-fast-path.py`, `python3 scripts/ci/test-reuse-merged-pr-test-artifacts.py`, `python3 scripts/ci/test-component-dependency-contract.py`, and relevant workflow contract tests.**
- [ ] **Step 6: Commit** `feat(ci): bind component fast path to exact provenance`.

### Task 3: Preserve component-scoped DAG and regression behavior

**Files:**
- Modify: `.github/workflows/build-components.yml`
- Modify: `.github/workflows/test-components.yml`
- Modify: `.github/workflows/release-components.yml`
- Modify: `scripts/ci/test-streaming-lakehouse-workflow.py`
- Create or modify: `scripts/ci/test-custom-component-workflow.py`

**Interfaces:**
- `start_component=<id>` schedules that component's check/build/test/release lifecycle and declared prerequisites only; `all` follows declared DAG order and each current repository package can fast-pass.
- Each workflow node consumes its prerequisite `stage_passed` output and gates on `needs.<job>.result == 'success'` plus explicit output.

- [ ] **Step 1: Add failing workflow tests** for every new dispatch choice, dependency edge, isolated component selection, all-components ordering, and failure isolation for independent components.
- [ ] **Step 2: Run targeted workflow tests and verify expected failures.**
- [ ] **Step 3: Wire component nodes via the reusable lifecycle** without duplicating Build/Test/Release stage implementation.
- [ ] **Step 4: Run `python3 scripts/ci/test-streaming-lakehouse-workflow.py`, the new custom workflow tests, YAML parsing, component config, fast-path and dependency tests.**
- [ ] **Step 5: Review `git diff --check` and confirm existing six components plus Kafka/Flink remain unchanged in the workflow contract.**
- [ ] **Step 6: Commit** `feat(ci): support scoped custom component lifecycles`.

## Completion Gate

- Catalog, dispatcher, evidence, exact-current fast path, and reusable workflow support service/integration components without any regression in existing jobs.
