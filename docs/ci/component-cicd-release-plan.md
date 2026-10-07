# BIGDATA Component CI/CD and Release Plan

## 1. Purpose

本文档定义 BIGDATA-1.0 在 Apache Ambari 3.0.0、Apache Bigtop 3.6.0、openEuler 22.x、RPM/DNF 基线下，其余核心组件的统一 CI/CD 与发布策略。

目标不是为每个组件单独创造一套流水线，而是形成：

```text
Build CI
  -> Test CI
  -> Ambari Compatibility CI
  -> Release CI
```

的统一组件发布模型。

## 2. Upstream Facts

### Apache Bigtop 3.6.0

Bigtop 负责：

- component source/BOM
- patch application
- Gradle component build tasks
- RPM spec
- package dependency graph
- repository artifacts

BIGDATA 当前 upstream stable BOM：

| Component | Version |
|---|---:|
| ZooKeeper | 3.8.4 |
| Hadoop | 3.4.3 |
| Hive | 4.0.1 |
| Tez | 0.10.5 |
| Spark | 3.5.8 |
| HBase | 2.6.5 |

### Apache Ambari 3.0.0

Ambari 负责：

- package/service metadata
- stack package mapping
- config generation
- lifecycle scripts
- Service Check
- Blueprint install
- HA orchestration

Ambari 3.0.0 source tree contains BIGTOP stack definitions for 3.2.0 and 3.3.0, including:

- ZOOKEEPER
- HDFS
- YARN
- HIVE
- TEZ
- SPARK
- HBASE

因此必须明确：

```text
Bigtop 3.6.0 build compatibility
!=
Ambari 3.0.0 BIGTOP stack compatibility
```

BIGDATA 必须维护一个显式的 Ambari compatibility gate，而不能假设 Ambari 3.0.0 自动认识 Bigtop 3.6.0 的 package suffix、version 和 filesystem layout。

## 3. Unified Pipeline

每个组件统一使用：

```text
Source/BOM
   ↓
Build CI
   ↓
RPM Artifact
   ↓
Test CI
   ↓
Tested RPM Artifact
   ↓
Ambari Contract Test
   ↓
Integration / HA Test
   ↓
Release CI
   ↓
Release Candidate Repository
```

### Build CI

职责：

- checkout exact Bigtop ref
- record Bigtop commit
- verify BOM version
- build component with required dependencies
- collect all RPMs
- generate checksums
- generate build evidence

默认：

```yaml
runner: ubuntu-latest
build_environment: openeuler/openeuler:22.03-lts-sp4
```

Gradle 模式：

```text
./gradlew <component>-rpm -Dbuildwithdeps=true
```

### Test CI

职责：

- download Build CI RPM artifacts
- start fresh openEuler container
- createrepo_c
- configure local DNF repo
- install by package name through DNF
- verify rpm metadata/files/dependencies
- process-level smoke
- re-upload tested RPMs
- generate test evidence

原则：

```text
Build environment and Test environment MUST be different.
```

### Ambari Compatibility CI

职责：

- validate Ambari package mapping
- validate Bigtop package suffix/name
- validate service metadata
- validate config directories
- validate lifecycle command paths
- run component-specific Ambari unit/contract tests
- validate Service Check contract

执行基线：

```yaml
ambari_ref: release-3.0.0
bigtop_ref: branch-3.6
```

如果 Ambari BIGTOP 3.3.0 stack 与 Bigtop 3.6.0 package contract 不一致：

```text
record delta
  -> maintain BIGDATA overlay
  -> test overlay
  -> never patch silently
```

### Release CI

只消费已经通过 Test CI 的 artifact。

职责：

- download tested RPMs
- download test evidence
- verify manifest/checksums
- construct release repository
- generate release manifest
- publish release bundle
- optionally create GitHub prerelease
- later publish stable DNF repository

禁止：

```text
Release CI rebuild source.
Release CI replace tested RPM with newly compiled RPM.
```

## 4. Component Waves

### Wave 1 — ZooKeeper

Version:

```yaml
zookeeper: 3.8.4
```

Build:

```text
zookeeper-rpm -Dbuildwithdeps=true
```

Build dependencies must include Bigtop utility packages required by RPM metadata.

Test:

- createrepo_c
- dnf install ZooKeeper base/server package
- rpm -qi
- rpm -ql
- rpm -qR
- start process
- ZooKeeper status
- zkCli connectivity
- stop process

Ambari:

- ZOOKEEPER metainfo package names
- zookeeper configuration paths
- server/client commands
- Service Check

Release Gate:

```yaml
build: PASS
dnf_install: PASS
runtime_smoke: PASS
ambari_contract: PASS
```

### Wave 2 — Hadoop / HDFS / YARN / MapReduce

Version:

```yaml
hadoop: 3.4.3
```

Build:

```text
hadoop-rpm -Dbuildwithdeps=true
```

Test layers:

#### Package

- Hadoop common/client packages
- HDFS packages
- YARN packages
- MapReduce packages
- package dependency resolution
- alternatives/config links

#### Process smoke

HDFS:

```text
NameNode format
NameNode start
DataNode start
hdfs dfs -mkdir
hdfs dfs -put
hdfs dfs -cat
```

YARN:

```text
ResourceManager start
NodeManager start
yarn node -list
simple application submission
```

Ambari:

- HDFS BIGTOP service metadata
- YARN service metadata
- MAPREDUCE2 metadata
- stack_packages.json
- package suffix mapping
- hadoop-env/core-site/hdfs-site/yarn-site
- Service Check scripts

Integration Gate:

```text
single-node smoke
  -> HDFS HA
  -> YARN HA
```

Release requires HDFS/YARN core smoke PASS; HA becomes RC gate.

### Wave 3 — Hive + Tez

Versions:

```yaml
hive: 4.0.1
tez: 0.10.5
```

Build:

```text
tez-rpm -Dbuildwithdeps=true
hive-rpm -Dbuildwithdeps=true
```

Dependency order:

```text
Hadoop
  -> Tez
  -> Hive
```

Test:

- install Hive/Tez from DNF repo
- Hive Metastore schema initialization
- start Metastore
- start HiveServer2
- JDBC/Beeline connectivity
- CREATE TABLE
- INSERT
- SELECT
- Tez execution engine smoke where enabled

Ambari:

- HIVE metainfo
- TEZ metainfo
- package suffixes
- hive-env
- hcat-env
- hdfs-site dependency
- Hadoop config dependencies
- service user/path contracts
- Service Check

Special Gate:

```text
Spark/Hive Metastore compatibility is not implied by Hive CI.
It is tested in the integration wave.
```

### Wave 4 — Spark

Version:

```yaml
spark: 3.5.8
```

Build:

```text
spark-rpm -Dbuildwithdeps=true
```

Test:

- install through DNF
- spark-shell version
- local spark-submit
- Spark SQL
- Spark on YARN
- event log / History Server
- Hive Metastore connectivity where included

Ambari:

- SPARK service metadata
- package mappings
- spark-defaults/spark-env
- History Server lifecycle
- Livy dependency only if included in release profile
- Service Check

Release Gate:

```yaml
local_submit: PASS
spark_sql: PASS
yarn_submit: PASS
ambari_contract: PASS
```

### Wave 5 — HBase

Version:

```yaml
hbase: 2.6.5
```

Build:

```text
hbase-rpm -Dbuildwithdeps=true
```

Dependency order:

```text
ZooKeeper
Hadoop/HDFS
  -> HBase
```

Test:

- DNF install
- standalone/local process smoke where practical
- HBase Master
- RegionServer
- shell create
- put
- get
- scan
- delete/drop

Ambari:

- HBASE metainfo
- HBase configuration
- HDFS config dependencies
- ZooKeeper config dependency
- package names
- lifecycle scripts
- Service Check

Integration:

- distributed HBase
- Master failover
- RegionServer recovery
- HDFS dependency

## 5. Component CI Matrix

| Component | Build CI | Package/DNF | Process Smoke | Ambari Contract | Multi-node/HA |
|---|---|---|---|---|---|
| ZooKeeper | GitHub hosted | GitHub hosted | GitHub hosted | GitHub hosted | external only for quorum/systemd |
| Hadoop/HDFS/YARN | GitHub hosted first | GitHub hosted | GitHub hosted first | GitHub hosted | external |
| Hive/Tez | GitHub hosted first | GitHub hosted | GitHub hosted first | GitHub hosted | external integration |
| Spark | GitHub hosted first | GitHub hosted | local smoke hosted | GitHub hosted | YARN cluster external |
| HBase | GitHub hosted first | GitHub hosted | local smoke hosted | GitHub hosted | external |

Escalate from hosted runner only when:

- disk exhaustion
- memory OOM
- repeat timeout
- systemd/kernel-specific behavior
- multi-node topology

## 6. Workflow Evolution

Current ZooKeeper workflows:

```text
build-component.yml
test-ci.yml
release-ci.yml
```

Next refactor target:

```text
build-component.yml
  inputs.component:
    zookeeper
    hadoop
    tez
    hive
    spark
    hbase

test-component.yml
  component-specific smoke adapter

ambari-contract.yml
  component-specific Ambari tests

release-component.yml
  tested-artifact-only release
```

Do not duplicate one YAML workflow per component unless component behavior cannot be modeled by inputs/matrix.

## 7. Change-aware CI

Mapping:

```text
BOM change
  -> affected component + downstream components

ZooKeeper patch
  -> ZooKeeper
  -> HBase compatibility

Hadoop patch
  -> Hadoop
  -> Hive/Tez
  -> Spark
  -> HBase

Hive/Tez patch
  -> Hive/Tez
  -> Spark SQL compatibility

Spark patch
  -> Spark

HBase patch
  -> HBase
```

## 8. Release Artifact Contract

Every component release contains:

```text
rpms/
repodata/
manifest/
evidence/
SHA256SUMS
release-manifest.yaml
```

Manifest minimum fields:

```yaml
schema: bigdata.release/v1
component:
component_version:
bigtop_version: 3.6.0
bigtop_commit:
ambari_version: 3.0.0
ambari_compatibility:
os: openEuler 22.x
arch:
jdk:
build_run:
test_run:
release_run:
status:
```

## 9. Release Stages

```text
CI Artifact
  -> TESTED
  -> RELEASE_CANDIDATE
  -> RC Repository
  -> HA/Ambari Validation
  -> STABLE
```

A GitHub Release is not automatically equal to STABLE.

Stable requires:

```yaml
build_evidence: PASS
install_evidence: PASS
component_smoke: PASS
ambari_contract: PASS
integration_required_for_component: PASS
release_manifest: PASS
checksums: PASS
```

## 10. Ambari Release Strategy

Ambari is treated as an independent management-plane compatibility dimension.

For BIGDATA-1.0:

```yaml
ambari: 3.0.0
bigtop: 3.6.0
```

Since Ambari 3.0.0 source currently contains BIGTOP 3.2.0/3.3.0 stack definitions, BIGDATA must establish one of:

```text
Option A:
Ambari existing stack contract is compatible with Bigtop 3.6 packages
  -> no overlay

Option B:
small package/path delta
  -> BIGDATA compatibility overlay

Option C:
substantial lifecycle/config delta
  -> explicit BIGTOP 3.6 stack adaptation track
```

Decision must be evidence-driven per component.

## 11. Recommended Implementation Order

```text
Wave 1 ZooKeeper
  -> prove Build/Test/Release pipeline

Wave 2 Hadoop
  -> generalize component workflow

Ambari Contract CI
  -> establish BIGTOP 3.6 compatibility overlay model

Wave 3 Hive/Tez

Wave 4 Spark

Wave 5 HBase

Full RC repository
  -> Ambari Blueprint
  -> 3M3W1G
  -> HA Validation
  -> BIGDATA-1.0 RC
```


## 12. Wave 3-5 parallel CI implementation

Implemented on branch `ci/wave3-5-components`.

Shared component matrix:

```text
ci/components.yaml
```

Core reusable scripts:

```text
scripts/ci/build-bigtop-component.sh
scripts/ci/test-bigtop-component.sh
```

Workflows:

```text
.github/workflows/build-components.yml
.github/workflows/test-components.yml
.github/workflows/ambari-component-contracts.yml
.github/workflows/release-components.yml
```

Components enabled:

| Component | Version | Build | Test | Ambari Contract | Release |
|---|---:|---|---|---|---|
| Tez | 0.10.5 | enabled | enabled | enabled | enabled |
| Hive | 4.0.1 | enabled | enabled | enabled | enabled |
| Spark | 3.5.8 | enabled | enabled | enabled | enabled |
| HBase | 2.6.5 | enabled | enabled | enabled | enabled |

The release workflow consumes tested RPM artifacts only and does not rebuild source.

## 13. Serial component validation on PR #43

The active Wave 3–5 workflow runs one component at a time, in this order:

```text
Tez Build -> Test -> Release Candidate
  -> Hive Build -> Test -> Release Candidate
  -> Spark Build -> Test -> Release Candidate
  -> HBase Build -> Test -> Release Candidate
```

Each step depends on the previous step succeeding. A failed build or install smoke
prevents later release candidates from being assembled. Automatic release steps
upload candidate artifacts only; publishing a GitHub prerelease still requires an
explicit manual dispatch. Maven and Gradle downloads are cached between successful
component jobs, while each job still builds and checks its RPMs independently.
Serial execution limits concurrent external downloads but does not increase an
individual GitHub-hosted runner's CPU or memory. The first cache miss can still be
slow, and the full pipeline's elapsed time is the sum of its component stages.

For a targeted rerun, manually dispatch `Build Components` with
`start_component` set to `tez`, `hive`, `spark`, or `hbase`. The selected component
starts at Build and continues through Test and Release Candidate, followed by
each remaining component in order. Earlier components are intentionally skipped
in that run; a targeted rerun does not replace a complete PR validation run.
