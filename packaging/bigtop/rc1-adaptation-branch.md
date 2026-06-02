# TASK-302 Bigtop RC1 Adaptation Branch

## 1. Metadata

```yaml
task: TASK-302
name: Create Bigtop RC1 Adaptation Branch
phase: M2-Prep
status: draft-ready
owner: Agent-B
```

## 2. Objective

为 BIGDATA-1.0 RC1 创建 Bigtop 适配工程分支，用于承载以下变更：

- RC1 目标版本 BOM patch
- openEuler22 RPM 适配
- 组件 RPM spec patch
- 构建依赖修正
- DNF repository 验证脚本
- 构建证据归档

该分支是 M2 Packaging Ready 的工程入口。

## 3. Branch Definition

```yaml
branch_name: bigdata-1.0-rc1-openeuler22-rpm
base_project: apache/bigtop
base_version: Bigtop 3.5.0
primary_os: openEuler22
package_type: rpm
package_manager: dnf
runtime: JDK8
```

## 4. Branch Creation Command

在 Build Lab 中执行：

```bash
export BIGDATA_RC1_HOME=/opt/bigdata-rc1
export BIGTOP_BASE_REF=<bigtop-3.5.0-tag-or-commit>

packaging/bigtop/create-rc1-adaptation-branch.sh \
  validation/bigtop/rc1-adaptation-branch.md
```

该脚本会完成：

```text
clone apache/bigtop if needed
fetch tags
checkout BIGTOP_BASE_REF if provided
verify clean working tree before patch
create or checkout bigdata-1.0-rc1-openeuler22-rpm
write validation/bigtop/rc1-adaptation-branch.md
```

实际 base commit 必须记录到 evidence。

## 5. Required Evidence

创建分支后必须记录：

```bash
git rev-parse HEAD
git status
git branch --show-current
```

归档到：

```text
validation/bigtop/rc1-adaptation-branch.md
```

## 6. RC1 Target Versions

该分支必须以项目目标版本为准：

```yaml
hadoop: 3.5.0
zookeeper: 3.9.5
hive: 4.2.0
hive_standalone_metastore: 4.2.0
tez: 0.10.5
spark: 3.5.8
hbase: 2.5.14
```

Bigtop 当前 BOM 中已有版本只用于差距识别，不用于自动降级 RC1 目标版本。

## 7. Allowed Changes

该分支允许修改：

```text
bigtop.bom
bigtop-packages/src/rpm/**
bigtop_toolchain/**
provisioner/docker/**
packages.gradle
build.gradle
```

允许新增：

```text
bigdata-rc1-notes/
```

用于记录临时补丁说明和构建问题。

## 8. Restricted Changes

该分支禁止进行以下变更，除非出现 Blocker：

- 改变 RC1 目标版本
- 引入 Kubernetes
- 引入 Streaming / Lakehouse
- 改为 DEB/APT 主线
- 引入自研 Packaging 系统替代 Bigtop
- 修改非 RC1 组件作为主线工作

## 9. Patch Sequence

建议变更顺序：

```text
PATCH-001 RC1 BOM Version Patch
PATCH-002 openEuler22 Toolchain Preflight Patch
PATCH-003 ZooKeeper 3.9.5 RPM Patch
PATCH-004 Hadoop 3.5.0 RPM Patch
PATCH-005 Hive 4.2.0 RPM Patch
PATCH-006 Spark 3.5.8 RPM Patch
PATCH-007 HBase 2.5.14 RPM Patch
PATCH-008 DNF Repository Script Patch
```

优先级：

```text
ZooKeeper
Hadoop
Hive
Spark
HBase
```

## 10. Commit Discipline

每个 commit 必须满足：

```yaml
one_commit_one_purpose: true
must_include:
  - component
  - version
  - reason
  - evidence_path_if_available
```

推荐 commit message：

```text
bigtop: adapt hadoop to 3.5.0 for rc1 rpm
bigtop: adapt hive to 4.2.0 for rc1 rpm
bigtop: add openeuler22 dependency preflight
```

## 11. Build Evidence Mapping

每个组件构建完成后，必须归档：

```text
validation/bigtop/<component>-<version>-rpm-build-log.md
validation/bigtop/<component>-<version>-rpm-package-list.txt
validation/bigtop/<component>-<version>-dnf-install.md
```

失败也必须归档：

```text
validation/bigtop/<component>-<version>-rpm-build-failure.md
```

失败日志比无日志更有价值。

## 12. Exit Criteria

TASK-302 完成条件：

```yaml
branch_created: PASS
base_commit_recorded: PASS
branch_name_verified: PASS
working_tree_clean_before_patch: PASS
rc1_patch_sequence_defined: PASS
```

## 13. Risks

### R-BRANCH-001: Bigtop 3.5.0 Tag Ambiguity

```yaml
severity: Medium
risk: 具体 release tag 或 branch 命名可能与预期不同。
mitigation: 记录实际 base commit，而不是只记录 tag 名称。
```

### R-BRANCH-002: Patch Scope Creep

```yaml
severity: High
risk: 适配分支可能逐渐包含非 RC1 能力。
mitigation: 严格限制 allowed changes 和 restricted changes。
```

### R-BRANCH-003: Version Change Drift

```yaml
severity: Critical
risk: 构建失败后容易回退版本绕过问题。
mitigation: 版本以 RC1 requirement decision 为准，失败必须转为适配问题或风险，不允许静默降级。
```

## 14. Decision

Bigtop RC1 适配分支正式作为 M2 Packaging Ready 的工程入口。

后续所有组件 RPM 构建工作必须基于该分支进行，并将证据归档到 `validation/bigtop/`。
