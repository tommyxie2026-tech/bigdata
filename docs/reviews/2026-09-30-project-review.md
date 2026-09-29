# BIGDATA Project Review — 2026-09-30

## 1. Review Scope

本次 Review 基于 `main` 分支当前事实状态，重点检查：

- 项目定位与 Roadmap
- BIGDATA-1.0 RC1 基线
- Bigtop/openEuler22 工程主线
- Packaging / Validation / Evidence
- Issue / Milestone / DoD 治理
- CI/CD 与 Release Engineering
- 文档一致性与执行可追溯性

Review 基线 commit：

```text
0370f88e71b001f28d72bd18f88834e109cef866
```

## 2. Executive Summary

当前项目应定义为：

```text
BIGDATA-1.0
= Reference Distribution
= Design Complete / Engineering Bootstrap / Packaging Not Ready
```

长期方向保持：

```text
BIGDATA-1.0  Reference Distribution
BIGDATA-2.0  Composable Platform
BIGDATA-3.0  Hybrid Data Platform
```

但当前阶段应停止继续扩大 2.0/3.0 范围，集中打通 BIGDATA-1.0 的真实发行链：

```text
Apache Bigtop
  -> openEuler 22
  -> RPM / DNF Repository
  -> ZooKeeper
  -> Hadoop / HDFS / YARN
  -> Hive / Tez
  -> Spark
  -> HA
  -> Ambari
  -> Validation Evidence
  -> BIGDATA-1.0 RC1
```

## 3. Review Findings

### R-001 — RC1 存在两套事实基线

**Severity:** Critical  
**Status:** OPEN  
**Area:** Baseline / Documentation / Release

旧文档仍大量以以下基线为主：

```yaml
os: Ubuntu 22.04
package: DEB
manager: apt
runtime: JDK8
```

而当前 RC1 实施主线已切换为：

```yaml
os: openEuler22
package: rpm
manager: dnf
runtime: JDK8
bigtop: 3.5.0  # repository baseline before 2026-09-30 refresh
```

主要受影响文档包括：

- `project/ROADMAP.md`
- `project/MILESTONES.md`
- `project/FEATURE_MAP.md`
- `docs/phase1-version-validation-plan.md`
- `bigtop/README.md`

**Required Action**

冻结唯一 RC1 execution truth：

```yaml
BIGDATA-1.0-RC1:
  os: openEuler 22.x
  package_format: RPM
  package_manager: DNF
  runtime: JDK8
  packaging_engine: Apache Bigtop 3.6.0
```

Ubuntu/DEB 降为 compatibility track，不得继续作为 RC1 主线。

**Exit Criteria**

- 所有 RC1 主文档使用同一 OS / package / repo 基线
- Ubuntu/DEB 被明确标记为兼容性或后续路线
- 不再出现同一 Milestone 同时要求 APT 与 DNF

---

### R-002 — Bigtop RC1 adaptation branch 尚未形成真实工程入口

**Severity:** Critical  
**Status:** OPEN  
**Area:** Packaging / Bigtop / M2

设计目标分支：

```text
bigdata-1.0-rc1-openeuler22-rpm
```

当前已存在 branch helper 和 runbook，但真实 evidence 仍为：

```yaml
status: NOT_EXECUTED
result: UNKNOWN
branch_created: UNKNOWN
```

**Required Action**

在真实 Bigtop 3.6.0 stable checkout 上执行：

```text
create adaptation branch
record base commit
verify clean tree
apply PATCH-001+
archive evidence
```

**Exit Criteria**

```yaml
branch_created: PASS
base_commit_recorded: PASS
branch_name_verified: PASS
working_tree_clean_before_patch: PASS
```

---

### R-003 — Validation 目录中 placeholder 与真实 evidence 混合

**Severity:** High  
**Status:** OPEN  
**Area:** Validation / Evidence

当前存在大量：

```yaml
status: NOT_EXECUTED
evidence_type: placeholder
result: UNKNOWN
```

文件存在并不能代表验证已完成。

**Required Action**

统一 evidence lifecycle：

```text
PLANNED
READY_TO_RUN
RUNNING
PASS
FAIL
BLOCKED
WAIVED
```

建议统一 metadata schema：

```yaml
schema: bigdata.evidence/v1
id:
component:
version:
environment:
stage:
status:
source:
execution:
result:
logs:
next_action:
```

**Exit Criteria**

- placeholder 不可被 Gate 统计为 progress
- PASS 必须包含真实 command/log/artifact
- release gate 可机器判断 evidence 状态

---

### R-004 — 缺少 Repository CI / Release Engineering CI

**Severity:** High  
**Status:** OPEN  
**Area:** CI/CD

当前 main 未形成标准 `.github/workflows/` CI 主线。

**Required Action**

至少建立：

```text
.github/workflows/
  lint.yml
  shellcheck.yml
  evidence-schema.yml
  rc1-preflight.yml
  bigtop-build.yml
  release-gate.yml
```

执行分层：

```text
L0 Repository CI
L1 Build CI
L2 Packaging CI
L3 Runtime CI
L4 Cluster / HA Validation
```

其中 L1+ 推荐使用 self-hosted openEuler runner。

**Exit Criteria**

- PR 必须有基础 CI gate
- evidence metadata 自动校验
- shell script 自动检查
- RC1 Build 可以通过 self-hosted runner 触发

---

### R-005 — README 已严重落后于项目真实定位

**Severity:** Medium  
**Status:** OPEN  
**Area:** Documentation / Product Positioning

当前 README 仍将项目描述为 references and notes。

**Required Action**

README 应明确项目是：

```text
Open, reproducible Hadoop ecosystem reference distribution
```

并展示：

- RC1 baseline
- component matrix
- current milestone status
- build/validation entrypoint
- release readiness

**Exit Criteria**

新成员仅阅读 README 即可理解：

- 项目是什么
- 当前做到哪里
- 当前唯一执行主线是什么
- 如何参与验证

---

### R-006 — Roadmap 正确，但 2.0/3.0 不应抢占当前实施资源

**Severity:** Medium  
**Status:** OPEN  
**Area:** Roadmap / Scope

长期路线保持：

```text
1.0 Reference Distribution
2.0 Composable Platform
3.0 Hybrid Data Platform
```

当前资源建议：

```text
BIGDATA-1.0  90%
BIGDATA-2.0   8%
BIGDATA-3.0   2%
```

**Required Action**

所有 2.0/3.0 工作进入 backlog / research track，不得阻塞 RC1。

**Exit Criteria**

- RC1 scope 无 Kubernetes / Lakehouse / Streaming 强制项
- Future capability 不能进入 M2/M3/M4 exit criteria

---

### R-007 — 组件适配应按 Build Wave 执行，避免并行扩散

**Severity:** High  
**Status:** OPEN  
**Area:** Execution Planning

建议按依赖顺序：

```text
Wave 0  openEuler Toolchain
Wave 1  ZooKeeper
Wave 2  Hadoop
Wave 3  Hive + Tez
Wave 4  Spark
Wave 5  HBase
```

第一条真正要跑通的是：

```text
ZooKeeper 3.9.5
  -> RPM Build
  -> Repository
  -> DNF Install
  -> systemd start
  -> zkCli smoke
  -> Evidence PASS
```

**Exit Criteria**

Wave 1 未 PASS，不扩大到后续组件的大规模适配。

---

### R-008 — Project Governance 文档存在引用漂移

**Severity:** Medium  
**Status:** OPEN  
**Area:** Governance

部分 Roadmap/DoD 文档引用的文件与当前仓库实际结构不完全一致，例如 backlog / issue tree 等治理资产需要重新核对。

**Required Action**

执行 repository documentation integrity check：

- referenced file exists
- referenced issue is current
- old baseline clearly marked historical
- active track / legacy track / future track 分层

**Exit Criteria**

不存在主线文档引用不存在或失效的执行入口。

---

### R-009 — 当前工程进度需要按 Release Evidence 重估

**Severity:** Medium  
**Status:** OPEN  
**Area:** Program Management

当前文档成熟度高于实际可交付成熟度。

建议状态：

```text
Architecture / Planning     75–85%
Engineering Bootstrap       35–40%
Actual RC1 Implementation   15–20%
```

该数字仅用于阶段判断，后续应以 evidence coverage 替代主观百分比。

**Required Action**

建立 milestone evidence coverage：

```text
M0 governance
M1 feasibility
M2 packaging
M3 core runtime
M4 HA
M5 RC1
```

**Exit Criteria**

Program Board 的状态以 Gate/Evidence 自动或半自动计算，而非手工判断。

---

### R-010 — 当前唯一 P0 主线应收缩为 M2 Wave 1

**Severity:** Critical  
**Status:** OPEN  
**Area:** Execution Priority

下一阶段不再继续补宏观设计，直接执行：

```text
openEuler Build Lab
  -> Bigtop 3.6.0 checkout
  -> upstream BOM delta review
  -> RC1 adaptation branch
  -> BOM Patch
  -> ZooKeeper 3.9.5 build
  -> RPM
  -> createrepo_c
  -> DNF repo
  -> dnf install
  -> ZooKeeper runtime
  -> Smoke PASS
```

目标 Gate：

```yaml
M2-WAVE1:
  build_lab: PASS
  bigtop_branch: PASS
  bom_patch: PASS
  toolchain_preflight: PASS
  zookeeper_rpm_build: PASS
  zookeeper_repo_publish: PASS
  zookeeper_dnf_install: PASS
  zookeeper_runtime: PASS
  evidence_complete: PASS
```

---

## 4. Priority Order

### P0

1. R-001 RC1 基线统一
2. R-011 Bigtop 3.6.0 BOM Delta Review
3. R-002 真实 Bigtop adaptation branch
4. R-010 M2 Wave 1 主线
5. R-003 Evidence 状态治理

### P1

5. R-004 CI/CD
6. R-007 Build Wave
7. R-008 Governance integrity

### P2

8. R-005 README
9. R-006 Future Scope 收敛
10. R-009 Progress Metrics

## 5. Review Decision

```yaml
decision: CONTINUE
release_state: NOT_READY
current_phase: Engineering Bootstrap
next_gate: M2-WAVE1
primary_goal: Build -> RPM -> Repo -> DNF -> Runtime -> Evidence
```

当前不建议继续扩大架构范围。

后续所有修复与实施应在 `project/REVIEW_ACTIONS.md` 中逐项跟踪关闭。


## 6. Stable Version Refresh — 2026-09-30

官方稳定版本重新核对结果：

```yaml
Apache Ambari: 3.0.0
Apache Bigtop: 3.6.0
```

决策：

- Ambari 3.0.0 保持不变。
- Bigtop 基线由 3.5.0 更新到 3.6.0。
- 新增 R-011，先比较 Bigtop 3.6.0 upstream BOM 与 BIGDATA 自定义目标 BOM。
- 后续 adaptation branch 必须基于 Bigtop 3.6.0，而不是 3.5.0。
- ZooKeeper Wave 1 的最终版本在 BOM Delta Review 后冻结。

关联 ADR：

- `docs/adr/ADR-018-ambari-bigtop-stable-baseline.md`
