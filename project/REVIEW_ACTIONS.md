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
| R-001 | P0 | 统一 RC1 为 openEuler22 + RPM/DNF 唯一事实基线 | IN_PROGRESS | Before M2 execution | TBD |
| R-002 | P0 | 基于 Bigtop 3.6.0 创建真实 RC1 adaptation branch | OPEN | M2-Prep | `validation/bigtop/rc1-adaptation-branch.md` |
| R-003 | P0 | 统一 Evidence lifecycle/schema，区分 placeholder 与真实 evidence | OPEN | M2-Wave1 | TBD |
| R-004 | P1 | 建立 Repository / Build / Release CI 分层 | IN_PROGRESS | M2 | `docs/ci/github-actions-ci-architecture.md`, `.github/workflows/ci-pr.yml`, `.github/workflows/ci-baseline.yml` |
| R-005 | P2 | 重写 README 对齐 Reference Distribution 定位 | OPEN | Before RC1 public review | TBD |
| R-006 | P2 | 2.0/3.0 收敛到 backlog，不阻塞 RC1 | OPEN | Immediate | Roadmap update |
| R-007 | P1 | 按 Wave 0~5 执行组件构建适配 | OPEN | M2/M3 | Component evidence |
| R-008 | P1 | 修复治理文档引用漂移与 legacy/active/future 分层 | OPEN | M2 | Documentation integrity report |
| R-009 | P2 | 用 Evidence Coverage 替代主观项目百分比 | OPEN | M2+ | Program Board |
| R-010 | P0 | 在 BOM Delta Review 后跑通选定 ZooKeeper 版本 Build→RPM→Repo→DNF→Runtime→Smoke | OPEN | M2-Wave1 | ZooKeeper build/install/runtime evidence |
| R-011 | P0 | 完成 Bigtop 3.6.0 upstream BOM 与 BIGDATA target BOM 差异评审 | OPEN | Before R-010 | `docs/adr/ADR-018-ambari-bigtop-stable-baseline.md` |
| R-012 | P1 | 建立 GitHub Actions 分层 CI：L0 GitHub-hosted，L1-L4 trusted environments | IN_PROGRESS | M2 | `docs/ci/github-actions-ci-architecture.md` |

## 4. Execution Order

```text
R-001
  ↓
R-011
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
  upstream_bom_delta_review: OPEN
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
-> Bigtop 3.6.0
-> Upstream BOM Delta Review
-> RC1 Adaptation Branch
-> Selected ZooKeeper RPM
-> DNF Repository
-> Runtime Smoke
-> Evidence PASS
```


## 8. CI Implementation Status

```yaml
CI-0:
  ci-pr: IMPLEMENTED
  ci-baseline: IMPLEMENTED
  runner: github-hosted
  public_fork_safe: true

CI-1:
  github_hosted_runner: IMPLEMENTED
  openeuler_container: openeuler/openeuler:22.03-lts-sp4
  self_hosted_openeuler_runner: FALLBACK_ONLY
  build_component_workflow: RUNNING_FIRST_VALIDATION
  first_target: zookeeper-3.8.4-on-bigtop-3.6.0

CI-2:
  rpm_repo_validation: NOT_STARTED
  runtime_smoke: NOT_STARTED

CI-3:
  multi_component_waves: NOT_STARTED

CI-4:
  cluster_ha_validation: NOT_STARTED
  release_gate: NOT_STARTED
```


## 9. CI-1 First Build Contract

```yaml
workflow: .github/workflows/build-component.yml
trigger:
  - workflow_dispatch
  - trusted_rc1_branch_push
runner:
  type: github-hosted
  label: ubuntu-latest
  build_container: openeuler/openeuler:22.03-lts-sp4
target:
  bigtop: 3.6.0
  zookeeper: 3.8.4
  jdk: 8
outputs:
  - rpm
  - build-log
  - package-list
  - checksums
  - evidence-summary
```

该 workflow 默认使用 GitHub-hosted runner。内部 PR 可执行组件构建；fork PR 不执行重型组件构建。self-hosted 仅作为资源不足或 systemd/HA 验证的 fallback。
