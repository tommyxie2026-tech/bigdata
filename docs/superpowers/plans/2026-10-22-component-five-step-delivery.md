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

## Current execution audit — 2026-10-22 (Asia/Tokyo)

Evidence baseline: main `0f84fa2c60852e73fa8994007076c1e36f844c96`.

| Task | Current state | Evidence / remaining condition |
|---|---|---|
| 1. Mainline CI and S3A | Delivered | #107 and #106 merged; original S3A acceptance 39621962743, SDK RPM/checksum/metadata on main; main CI success |
| 2. Deduplication and timing | Delivered for this iteration | #108/#120 merged; main Build Components 39689437161 success; artifact 12388645845 preserves original Trino build/test 38450621685 as verified repository reuse |
| 3. Dependency proxy | CI implementation delivered; production deployment incomplete | #110/#115 merged; full component run 39689622642 PASS, cold/warm/offline 265/47/39 seconds with 1408 dependencies; actual host/HTTPS domain and production CI connection still required |
| 4. Dual CDC lakehouse recovery | Delivered for the specified profiles | Main runs 39689554165 (local Paimon), 39689554220 (Paimon HDFS), 39689554168 (Paimon HTTPS S3), 39689554558 (Hudi HDFS), 39689554289 (Iceberg HDFS) success; not universal exactly-once/schema-evolution or production HA claims |
| 5. Metrics RPM and publication | Delivered for standalone acceptance | Original actual run 39653729447; release 39691186873 success; #123 merged with two RPMs, checksums, real query/restart evidence and metadata; remote objects available |

The five-step goal is not wholly complete because task 3 still lacks its real deployment. Separately, the wider platform roadmap has implementation gaps (Ambari cluster integration, shared catalogs, security/observability, product and cloud-native features); these are not silently removed by completing component CI. See [engineering roadmap](../../roadmap.md).

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
- [x] Repair PR #107 merged as 2d4826a; main Hue run 39631347762 and PostgreSQL run 39631347479 actually succeeded.

### Task 2: Reduce duplicated CI and measure time

Files: scripts/ci/reuse_merged_pr_test_artifacts.py and its tests; reusable lifecycle workflows; scripts/ci/component input/CI timing utilities; docs/ci/dependency-resilience.md.

- [x] #108 added component-scoped payload/test identity with dependency/shared-script closure.
- [x] #108 requires successful actual component tests, required CI, trusted original builds and retained artifacts before reuse.
- [x] Emit reuse decision, original build/test provenance, cache state and queue/build/test durations as structured evidence.
- [x] #108 validated positive and negative scope/provenance cases.
- [x] #108 merged as 195f709; all eight push workflows succeeded. Hue report artifact 12360840301 records 265s repository check and skipped stage durations as null; Hudi representative dispatch 39628608297 reused original RPM without repeat Build/Test.

### Task 3: Connect a dependency proxy

Files: infra/dependency-proxy/ deployment profile; scripts/ci proxy probe/tests; independent dependency-policy workflow and documentation.

- [ ] Discover existing endpoint/host configuration and obtain an authorized real deployment target.
- [x] Implement a pinned deployment profile with persistent storage, health/readiness checks and bounded client behavior.
- [x] Test cold fetch, warm fetch while upstream is unavailable, checksum preservation and restart persistence in CI.
- [ ] Deploy to the real target, set repository mirror configuration, and verify one representative component cold/warm/offline cycle. Keep other components online until their dependency closures are proven.

### Task 4: CDC to lakehouse, then remote storage

Files: scripts/cdc-lakehouse/ contracts, source-specific adapters and Java harness; .github/workflows/cdc-lakehouse.yml.

- [x] Start with published MySQL/PostgreSQL CDC, Flink and Paimon RPMs; retain immutable source/checksum evidence.
- [x] Validate snapshot and I/U/D against exact final source rows, completed checkpoints, stop/savepoint and resumed incremental changes.
- [x] Verify HDFS/S3 persisted storage and a fresh-process read after restart; extend the proven harness separately to Iceberg/Hudi without replacing the Paimon acceptance target.
- [x] Submit independent PR(s), track actual openEuler tests and update matrix status only from successful evidence.

### Task 5: Ambari Metrics

Files: standalone Metrics contract, build/test adapters, .github/workflows/ambari-metrics.yml, documentation/matrix.

- [x] Inspect immutable Ambari 3.0.0 Metrics source/recipe, exact packages and runtime requirements.
- [x] Implement Collector/Monitor packaging or the supported upstream recipe independently of the existing Ambari Server RPM.
- [x] Run clean openEuler installation, agent submission and timestamped real metric queries, then restart and query persistence/recovery.
- [x] Verify candidate/checksum/metadata, create promotion PR for review and update component status with exact evidence.

## Completion audit

The goal remains active until all five tasks have their full acceptance evidence. Repository code, fixture success or an unmerged PR alone does not prove actual proxy deployment, full component offline readiness, lakehouse recovery or Metrics delivery. Log external blockers precisely and keep advancing unaffected work.

## Delivery ledger — 2026-10-22 continuation

Historical entries below describe the state when each action happened; the Current execution audit above supersedes their pending-state descriptions.

- Progress: #109 merged as 56f3737 after actual MySQL and PostgreSQL → Paimon run 39637652324 passed. Small evidence artifacts 12364930947/12364840331 prove exact snapshot/IUD/restored values, checkpoint and savepoint paths. Main post-merge run 39641238958 also succeeded. This is local-filesystem warehouse evidence only.
- Progress: #111 merged as fd967df. Original successful Collector source run 39637960371 is reused by RPM packaging; Monitor #112 merged as e52b289 after actual run 39639490456 proved repeated fresh CPU/memory emissions before/after restart. Main Monitor run 39641267918 also succeeded. Neither proves the real Collector persistence requirement.
- Progress: #113 implements actual Collector/Monitor RPMs and strict Collector historical/new timestamp assertions. Initial packaging correctly rejected a nonmatching Bigtop Phoenix archive; it now uses the original Apache archive and retains only verified downloads. Actual RPM installation/persistence remains pending.
- Ruling: user chose an open-source combination instead of Nexus onboarding. #110 now uses Reposilite/Verdaccio/devpi with persistent volumes and TLS; real deployment host/domain is still required. The fixture must pass actual byte, physical egress isolation and restart proof before any cache-success claim.
- Next stage: an independent HDFS matrix uses separate storage/client containers, guarded NameNode formatting, checkpoint/savepoint recovery and a fresh final-row reader after storage restart. This is not evidence for S3A or Iceberg/Hudi; those remain required follow-on work.
- Remaining audit: complete per-stage timing/provenance coverage, actual production proxy and representative full component cold/warm/offline closure, remote HDFS/S3 plus Iceberg/Hudi, and actual Metrics RPM installation/query/restart and reviewed repository promotion. No new PR is automatically merged.

- Progress (current audit): #106/#110/#113–#123 delivery changes have been reviewed and merged where applicable; Metrics repository publication is complete, and main dual CDC / proxy / component CI evidence is recorded above. Production proxy deployment remains incomplete. The matrix and roadmaps now distinguish remaining integration development from deployment/test work.
