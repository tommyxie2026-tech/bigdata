# TASK-202 Bigtop Hadoop Build Support Review

## 1. Metadata

```yaml
task: TASK-202
name: Bigtop Hadoop Build Support Review
owner: Agent-B
sprint: Sprint-1
status: completed-initial-review
result: CONDITIONAL_GO
confidence: high-for-version-gap
```

## 2. Objective

验证 Apache Bigtop 当前源码配置对 Hadoop 的支持情况，并判断 BIGDATA-1.0 RC1 是否应继续坚持 Hadoop 3.5.0 作为默认候选，或调整为 Bigtop 当前可见配置中的 Hadoop 3.4.3。

本任务不是一次真实构建验证，不声明 Hadoop 包已构建成功。

## 3. Method

公开源码配置级验证：

- 检查 `apache/bigtop` 当前 `bigtop.bom`
- 检查 Hadoop 组件版本定义
- 检查 Hadoop DEB packaging 文件是否存在
- 对比 BIGDATA-1.0 原候选版本与 Bigtop 当前源码配置

## 4. Findings

### 4.1 Bigtop BOM Defines Hadoop 3.4.3

当前 `apache/bigtop` 主线 `bigtop.bom` 中 Hadoop 组件定义为：

```groovy
'hadoop' {
  name = 'hadoop'
  version { base = '3.4.3'; pkg = base; release = 1 }
}
```

Evidence:

- `apache/bigtop:bigtop.bom`

### 4.2 Hadoop DEB Packaging Exists

Bigtop 存在 Hadoop 的 DEB packaging control 文件：

```text
bigtop-packages/src/deb/hadoop/control
```

该文件定义了多个 Hadoop 相关 DEB 包，包括：

- hadoop
- hadoop-hdfs
- hadoop-yarn
- hadoop-mapreduce
- hadoop-client
- hadoop-conf-pseudo
- hadoop-yarn-nodemanager

Evidence:

- `apache/bigtop:bigtop-packages/src/deb/hadoop/control`

### 4.3 Bigtop Current Mainline Version Differs From Previous BIGDATA Candidate

BIGDATA-1.0 原始候选：

```yaml
hadoop: 3.5.0
```

Bigtop 当前主线 BOM 可见配置：

```yaml
hadoop: 3.4.3
```

这意味着 Hadoop 3.5.0 不能直接视为已被 Bigtop 当前主线覆盖。

### 4.4 Bigtop Stack Uses JDK Configurable By BIGTOP_JDK

Bigtop BOM 中 stack JDK 版本通过环境变量 `BIGTOP_JDK` 控制，默认值为 `8`：

```groovy
'jdk' { version = "1." + ( System.getenv('BIGTOP_JDK') ?: "8" ); version_base = version }
```

这与 BIGDATA-1.0 JDK8 优先策略一致。

## 5. Risks

### R-B202-001: Hadoop 3.5.0 Not Proven In Bigtop Current BOM

Severity: Critical

当前公开源码配置显示 Hadoop 为 3.4.3，而不是 3.5.0。

如果坚持 Hadoop 3.5.0，需要额外验证：

- 修改 `bigtop.bom` 到 Hadoop 3.5.0
- Hadoop 3.5.0 源码包下载路径
- 编译依赖变化
- DEB packaging 是否兼容
- 与 Hive/Spark/YARN/Tez 的兼容性

### R-B202-002: RC1 Version Freeze Cannot Use Hadoop 3.5.0 Without Real Build Evidence

Severity: Critical

Hadoop 3.5.0 目前仍只能作为“社区最新稳定优先候选”，不能作为 RC1 冻结版本。

### R-B202-003: Hadoop 3.4.3 Is Better Candidate For RC1 Build Path

Severity: Medium

Hadoop 3.4.3 已出现在 Bigtop 当前 BOM 中，作为 RC1 初始构建路径的风险明显低于 Hadoop 3.5.0。

## 6. Recommendation

```yaml
result: CONDITIONAL_GO
rc1_recommended_hadoop: 3.4.3
hadoop_3_5_0_status: evaluation_only
reason:
  - Bigtop current BOM defines Hadoop 3.4.3.
  - Hadoop DEB packaging exists in Bigtop.
  - Hadoop 3.5.0 is not proven by current Bigtop BOM evidence.
next_action:
  - Treat Hadoop 3.4.3 as RC1 primary build candidate.
  - Keep Hadoop 3.5.0 as upgrade/evaluation candidate.
  - Run real Bigtop build for Hadoop 3.4.3 first.
  - Only evaluate Hadoop 3.5.0 after RC1 repository path is proven.
```

## 7. Decision

For BIGDATA-1.0 RC1, Hadoop should be adjusted from:

```yaml
hadoop: 3.5.0
```

to:

```yaml
hadoop: 3.4.3
```

until Hadoop 3.5.0 has real Bigtop build evidence.

This is a Scope Lock decision for RC1, not a rejection of Hadoop 3.5.0 for future versions.
