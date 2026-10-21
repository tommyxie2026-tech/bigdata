# Component five-step delivery implementation plan

> **For agentic workers:** Execute task-by-task in the current session using superpowers:executing-plans. Preserve the full five-step goal across turns; do not stop at a green fixture.

**Goal:** Close mainline CI, remove redundant component work, connect a real dependency proxy, verify CDC-to-lakehouse persistence/recovery, and deliver Ambari Metrics with actual collection/query/restart tests.

**Architecture:** Use small independent PRs, existing published RPMs and isolated openEuler workflows. Build payload identities are distinct from download-policy and test identities. Every stage records source, runtime, checksum and actual job evidence; deployment and integration remain unproven until run against a live service.

**Tech Stack:** GitHub Actions, Python/Bash, Maven/Gradle, Docker/openEuler 22.03 LTS SP4, Flink 1.20.1, CDC 3.4.0, Paimon 2.1.0, Hadoop 3.4.3, Ambari 3.0.0.

**Spec:** The five next steps approved in this thread; existing docs/component-ci-backlog.md and docs/ci/dependency-resilience.md define component boundaries and acceptance gates.

## Global constraints

- No automatic merge of new repair, feature or repository-promotion PRs.
- Do not download large RPM/JAR artifacts locally; execute runtime builds/tests on CI.
- Reuse immutable existing RPMs when source/toolchain/package inputs match; preserve original provenance.
- Skipped/cancelled jobs never count as actual build or functional-test success.
- Source/compatibility identity, checksum, clean installation and functional evidence remain release gates.
- No production proxy endpoint is present in repository configuration; request a real deployment target while implementing/verifying the deployment profile independently.

## Review focus

- A verified repository on main must pass the lifecycle gate even when PR-only builds are required.
- Download-policy changes must not invalidate a stable connector RPM; packaging/contract changes must invalidate reuse.
- Reused RPM evidence must keep its original build identity rather than claiming current-input provenance.
- A warm offline fixture cannot establish a component's complete offline dependency closure.
- CDC recovery must compare exact final rows after source changes while stopped, and Metrics must query real timestamps and survive restart.

### Task 1: Close the mainline failures

Files: .github/workflows/component-lifecycle.yml; scripts/ci/test-component-lifecycle-gate.py; scripts/flink-cdc-postgres/select_rpm.py and test_select_rpm.py; .github/workflows/ci-pr.yml.

- [x] Refresh main and actual push jobs. Baseline e1bd5f0: CI PR, dependency policy and standalone Hadoop/ZooKeeper checks passed; Hue gate and PostgreSQL promotion failed. S3A run 39621962743 passed and created optional SDK promotion PR #106.
- [x] Write failing tests executing the lifecycle gate for main/PR/failed-check cases.
- [x] Write selector tests separating unchanged package recipes from changed retry policy, retaining original build identity and rejecting changed payload inputs.
- [x] Implement minimal fixes and validate behavior/contracts. Live API proof selects original published Build 39124662344 with identity c0c725259e316dd63d254dd2d818ebeefeda1123980452cf77f3a384dc4da2b0; no RPM was downloaded locally.
- [ ] Create an independent repair PR, track its latest head, and present the reviewed/green result for merge. Recheck main after merge.

### Task 2: Reduce duplicated CI and measure time

Files: scripts/ci/reuse_merged_pr_test_artifacts.py and its tests; reusable lifecycle workflows; scripts/ci/component input/CI timing utilities; docs/ci/dependency-resilience.md.

- [ ] Add conservative component-scoped payload/test identity closure with dependency and shared-script coverage.
- [ ] Reuse actual successful component-specific PR tests after merge even when unrelated files changed, requiring CI success, trusted source and both evidence/tested-RPM artifacts.
- [ ] Emit reuse decision, original build/test provenance, cache state and queue/build/test durations as structured evidence.
- [ ] Validate positive reuse and negative cases (changed test/recipe/dependency, expired artifact, skipped/failed job, foreign repository).
- [ ] Submit and verify a separate CI-efficiency PR, then measure a mainline warm run after merge.

### Task 3: Connect a dependency proxy

Files: infra/dependency-proxy/ deployment profile; scripts/ci proxy probe/tests; independent dependency-policy workflow and documentation.

- [ ] Discover existing endpoint/host configuration and obtain an authorized real deployment target.
- [ ] Implement a pinned deployment profile with persistent storage, health/readiness checks and bounded client behavior.
- [ ] Test cold fetch, warm fetch while upstream is unavailable, checksum preservation and restart persistence in CI.
- [ ] Deploy to the real target, set repository mirror configuration, and verify one representative component cold/warm/offline cycle. Keep other components online until their dependency closures are proven.

### Task 4: CDC to lakehouse, then remote storage

Files: scripts/cdc-lakehouse/ contracts, source-specific adapters and Java harness; .github/workflows/cdc-lakehouse.yml.

- [ ] Start with published MySQL/PostgreSQL CDC, Flink and Paimon RPMs; retain immutable source/checksum evidence.
- [ ] Validate snapshot and I/U/D against exact final source rows, completed checkpoints, stop/savepoint and resumed incremental changes.
- [ ] Verify HDFS/S3 persisted storage and a fresh-process read after restart; extend the proven harness separately to Iceberg/Hudi without replacing the Paimon acceptance target.
- [ ] Submit independent PR(s), track actual openEuler tests and update matrix status only from successful evidence.

### Task 5: Ambari Metrics

Files: standalone Metrics contract, build/test adapters, .github/workflows/ambari-metrics.yml, documentation/matrix.

- [ ] Inspect immutable Ambari 3.0.0 Metrics source/recipe, exact packages and runtime requirements.
- [ ] Implement Collector/Monitor packaging or the supported upstream recipe independently of the existing Ambari Server RPM.
- [ ] Run clean openEuler installation, agent submission and timestamped real metric queries, then restart and query persistence/recovery.
- [ ] Verify candidate/checksum/metadata, create promotion PR for review and update component status with exact evidence.

## Completion audit

The goal remains active until all five tasks have their full acceptance evidence. Repository code, fixture success or an unmerged PR alone does not prove actual proxy deployment, full component offline readiness, lakehouse recovery or Metrics delivery. Log external blockers precisely and keep advancing unaffected work.
