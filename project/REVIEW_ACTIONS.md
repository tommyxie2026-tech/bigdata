# BIGDATA Review Action Tracker

## 1. Purpose

本文件是 BIGDATA 项目架构与工程 Review 的长期行动跟踪入口。

原则：

```text
Every review finding must have:
Owner + Priority + Status + Exit Criteria + Evidence
```

Review 原文：

- `docs/reviews/2026-09-30-project-review.md`

## 2. Status Model

```text
OPEN
IN_PROGRESS
BLOCKED
READY_FOR_REVIEW
DONE
WONT_DO
```

DONE 必须满足：

```text
Exit Criteria satisfied
+ Evidence archived
+ Review completed when required
```

## 3. Action List

| ID | Priority | Finding | Status | Target | Evidence |
|---|---|---|---|---|---|
| R-001 | P0 | 统一 RC1 为 openEuler22 + RPM/DNF 唯一事实基线 | OPEN | Before M2 execution | TBD |
| R-002 | P0 | 创建真实 Bigtop RC1 adaptation branch | OPEN | M2-Prep | `validation/bigtop/rc1-adaptation-branch.md` |
| R-003 | P0 | 统一 Evidence lifecycle/schema，区分 placeholder 与真实 evidence | OPEN | M2-Wave1 | TBD |
| R-004 | P1 | 建立 Repository / Build / Release CI 分层 | OPEN | M2 | TBD |
| R-005 | P2 | 重写 README 对齐 Reference Distribution 定位 | OPEN | Before RC1 public review | TBD |
| R-006 | P2 | 2.0/3.0 收敛到 backlog，不阻塞 RC1 | OPEN | Immediate | Roadmap update |
| R-007 | P1 | 按 Wave 0~5 执行组件构建适配 | OPEN | M2/M3 | Component evidence |
| R-008 | P1 | 修复治理文档引用漂移与 legacy/active/future 分层 | OPEN | M2 | Documentation integrity report |
| R-009 | P2 | 用 Evidence Coverage 替代主观项目百分比 | OPEN | M2+ | Program Board |
| R-010 | P0 | 跑通 ZooKeeper 3.9.5 Build→RPM→Repo→DNF→Runtime→Smoke | OPEN | M2-Wave1 | ZooKeeper build/install/runtime evidence |

## 4. Execution Order

```text
R-001
  ↓
R-002
  ↓
R-003
  ↓
R-010
  ↓
R-004 / R-007 / R-008
  ↓
R-005 / R-006 / R-009
```

## 5. M2-Wave1 Gate

```yaml
M2-WAVE1:
  build_lab: OPEN
  bigtop_branch: OPEN
  bom_patch: OPEN
  toolchain_preflight: OPEN
  zookeeper_rpm_build: OPEN
  zookeeper_repo_publish: OPEN
  zookeeper_dnf_install: OPEN
  zookeeper_runtime: OPEN
  evidence_complete: OPEN
```

## 6. Update Rules

每次解决 Review 项时必须同时更新：

1. 本文件 Status
2. 对应 Evidence
3. 必要的 Roadmap / Milestone / DoD
4. 对应 Issue / PR
5. Remaining Risk

推荐关闭记录：

```yaml
id: R-xxx
status: DONE
resolved_by:
  - PR/commit
evidence:
  - path
remaining_risk:
  - item
reviewed_at:
```

## 7. Current Focus

当前唯一 P0 工程主线：

```text
M2-Wave1:
openEuler22
-> Bigtop 3.5
-> RC1 Adaptation Branch
-> ZooKeeper 3.9.5 RPM
-> DNF Repository
-> Runtime Smoke
-> Evidence PASS
```
