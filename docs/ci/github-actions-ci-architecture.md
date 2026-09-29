# BIGDATA GitHub Actions CI Architecture Review

## 1. Review Date

2026-09-30

## 2. Scope

本评审针对 BIGDATA-1.0 RC1 的迭代编译与测试流水线，目标是判断 GitHub Actions 是否适合承载：

- Repository lint / policy
- Bigtop 3.6.0 baseline validation
- openEuler 22.x RPM build
- DNF repository generation
- Package install validation
- Runtime smoke test
- Multi-component integration
- 3M3W1G / HA validation
- Release evidence generation

当前基线：

```yaml
repository: tommyxie2026-tech/bigdata
visibility: public
ambari: 3.0.0
bigtop: 3.6.0
os: openEuler 22.x
package: RPM
manager: DNF
```

## 3. Review Decision

GitHub Actions 适合作为 BIGDATA 的 CI Orchestrator，但不应把所有任务都运行在 GitHub-hosted runner。

推荐：

```text
GitHub Actions
    |
    +-- L0 GitHub-hosted: fast / untrusted-safe
    |
    +-- L1-L3 trusted self-hosted openEuler build/test runners
    |
    +-- L4 dedicated cluster validation environment
```

核心原则：

```text
PR checks are cheap and isolated.
Heavy builds run only for trusted code.
Runtime/HA tests run only on controlled environments.
Every heavy run produces auditable evidence.
```

## 4. Security Boundary

本仓库为 public repository。

因此：

```text
pull_request from forks
    -> GitHub-hosted runners ONLY
    -> NEVER self-hosted build lab
```

Self-hosted runner 只允许：

```text
push to trusted branches
workflow_dispatch by maintainers
release/tag
approved internal branch workflows
```

禁止：

```text
public fork PR
  -> direct self-hosted runner execution
```

## 5. CI Layer Model

### L0 — Repository CI

Runner:

```yaml
runs-on: ubuntu-latest
```

Trigger:

```text
pull_request
push
```

Tasks:

- YAML validation
- Shell syntax
- ShellCheck
- Evidence schema validation
- RC1 baseline consistency
- stale baseline detection
- BOM delta static validation
- lightweight script tests

目标：

```text
< 5 minutes
required for every PR
```

### L1 — Bigtop Compile CI

Runner labels:

```yaml
runs-on:
  - self-hosted
  - linux
  - openeuler22
  - x64
  - bigtop-build
```

Trigger:

```text
workflow_dispatch
trusted branch push
optional trusted schedule
```

Build Wave：

```text
Wave 0  toolchain
Wave 1  ZooKeeper
Wave 2  Hadoop
Wave 3  Hive + Tez
Wave 4  Spark
Wave 5  HBase
```

支持三种模式：

```text
component build
wave build
full RC build
```

输出：

- RPM
- source commit
- Bigtop commit
- full/relevant build logs
- package list
- checksums
- evidence metadata

### L2 — Packaging / Repository CI

Input:

```text
L1 RPM artifacts
```

执行：

```text
rpm metadata validation
rpm -qpi / rpm -qpl
dependency inspection
createrepo_c
DNF repository metadata
dnf makecache
dnf search
dnf install
```

原则：

> 安装测试不能污染持久化 build runner。

建议使用：

```text
disposable openEuler VM
or ephemeral self-hosted runner
```

输出：

- repository snapshot
- repodata
- install log
- RPM manifest
- dependency report

### L3 — Runtime Smoke CI

Input:

```text
validated L2 repository
```

Wave 1：

```text
install ZooKeeper RPM
  -> systemd start
  -> systemctl status
  -> zkCli basic connectivity
  -> stop/restart
  -> PASS/FAIL evidence
```

后续：

```text
HDFS:
  mkdir / put / cat / rm

YARN:
  application submit

Hive:
  create / insert / select

Spark:
  spark-submit / Spark SQL

HBase:
  create / put / get / scan
```

### L4 — Cluster / HA CI

普通 PR 不执行。

Trigger：

```text
workflow_dispatch
nightly/weekly trusted schedule
RC candidate
```

环境：

```text
3 Master
3 Worker
1 Gateway
```

验证：

- ZooKeeper quorum
- HDFS HA
- YARN HA
- Hive service availability
- Spark on YARN
- HBase failover（如进入 RC1）
- Ambari install / lifecycle / Service Check

输出：

```text
Validation Report
Known Issues
Gate Decision
```

## 6. Workflow Layout

目标结构：

```text
.github/workflows/
├── ci-pr.yml
├── ci-baseline.yml
├── build-component.yml
├── package-repo.yml
├── runtime-smoke.yml
├── cluster-validation.yml
└── release-gate.yml
```

当前第一阶段只实施：

```text
ci-pr.yml
ci-baseline.yml
```

重型 workflow 在 self-hosted runner 准备完成后逐步引入。

## 7. Trigger Strategy

### PR

```yaml
pull_request:
```

仅 L0。

### Trusted branch

```yaml
push:
  branches:
    - main
    - bigdata-1.0-rc1-openeuler22-rpm
```

执行 L0，并可扩展 selected L1。

### Manual

```yaml
workflow_dispatch:
```

用于：

- component builds
- wave builds
- runtime smoke
- cluster validation

### Scheduled

待流水线稳定后再引入：

```text
nightly: selected build/smoke
weekly: full stack
pre-RC: HA
```

## 8. Change-Aware Build Selection

避免任何修改都触发完整 Hadoop 生态构建。

建议：

```text
docs/**
  -> L0 only

packaging/bigtop/patches/zookeeper/**
  -> ZooKeeper

packaging/bigtop/patches/hadoop/**
  -> Hadoop + affected downstream validation

packaging/bigtop/patches/hive/**
  -> Hive + Tez

packaging/bigtop/patches/spark/**
  -> Spark

bigtop.bom / version matrix
  -> BOM delta + affected wave
```

后续通过 changed-files 输出动态 matrix。

## 9. Matrix Strategy

GitHub Actions matrix 适合独立的架构/组件组合，但 RC1 初期不应矩阵爆炸。

目标能力：

```yaml
matrix:
  arch:
    - x86_64
    - aarch64
  component:
    - zookeeper
    - hadoop
```

初期：

```text
x86_64 first
one component per wave
aarch64 after x86_64 pipeline is stable
```

## 10. Cache and Artifact Strategy

Cache 用于可再生依赖：

- Gradle cache
- Maven cache
- source archive cache

Artifact 用于本次执行产物：

- RPM
- logs
- checksums
- package manifest
- repository metadata
- evidence JSON/Markdown

Release 不能依赖 cache 作为事实来源。

## 11. Evidence Integration

所有 L1-L4 job 最终应生成统一 metadata：

```yaml
schema: bigdata.evidence/v1
component:
version:
bigtop_ref:
source_commit:
environment:
stage:
status:
artifacts:
logs:
started_at:
completed_at:
```

状态：

```text
PASS
FAIL
BLOCKED
```

GitHub Actions artifact 是短期运行产物；
经过评审的摘要 evidence 再提交到：

```text
validation/**
```

## 12. Concurrency

建议避免同一个 RC1 组件同时执行多个重构建：

```yaml
concurrency:
  group: bigdata-${{ inputs.component }}-${{ github.ref }}
  cancel-in-progress: false
```

Release/HA job 不允许自动 cancel。

## 13. Runner Topology

建议：

```text
GitHub-hosted
  -> L0

openEuler Build Runner
  -> L1 only

Disposable openEuler Test Runner
  -> L2 / L3

Validation Cluster Controller
  -> L4
```

不要让一台机器同时承担 Build + Install + Cluster HA 全部职责。

## 14. Rollout Plan

### CI-0

```text
ci-pr.yml
ci-baseline.yml
```

目标：让每个 PR 都有稳定、快速、无需秘密信息的检查。

### CI-1

```text
self-hosted openEuler runner
build-component.yml
ZooKeeper Wave 1
```

### CI-2

```text
package-repo.yml
runtime-smoke.yml
```

### CI-3

```text
Hadoop/Hive/Spark build waves
dynamic matrix
```

### CI-4

```text
3M3W1G cluster-validation.yml
release-gate.yml
```

## 15. Review Result

```yaml
decision: GO
architecture: layered-github-actions
public_pr_runner: github-hosted-only
heavy_build_runner: trusted-self-hosted-openeuler
cluster_validation: dedicated-environment
initial_scope:
  - ci-pr
  - ci-baseline
next_scope:
  - self-hosted-runner
  - zookeeper-wave1
```
