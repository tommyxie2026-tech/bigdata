# TASK-101 Ambari Community Activity Review

## 1. Metadata

```yaml
task: TASK-101
name: Ambari Community Activity Review
owner: Agent-A
sprint: Sprint-1
status: completed-initial-review
result: CONDITIONAL_GO
confidence: medium
```

## 2. Objective

判断 Apache Ambari 是否仍值得作为 BIGDATA-1.0 RC1 的候选 Backend Plugin 继续投入验证。

本任务只验证社区与发布状态，不验证 Ubuntu 22.04 安装、JDK 8 运行、Hadoop 3.5 管理能力。

## 3. Method

公开资料核对：

- Apache 下载目录
- Apache Ambari GitHub 仓库
- Ambari 3.0.0 Release 信息
- Ambari 仓库基础活跃度信号

## 4. Findings

### 4.1 ASF Release Exists

Apache 下载目录存在以下版本：

- ambari-2.6.2
- ambari-2.7.7
- ambari-2.7.8
- ambari-2.7.9
- ambari-3.0.0
- ambari-metrics-3.0.0

这说明 Ambari 3.0.0 与 Ambari Metrics 3.0.0 均存在 ASF 下载目录，可进入后续源码与签名校验。

Evidence:

- https://downloads.apache.org/ambari/

### 4.2 GitHub Repository Active Enough For Initial Review

Apache Ambari GitHub 仓库为公开仓库，当前页面显示：

```yaml
repository: apache/ambari
branch: trunk
commits: 25090
stars: 2300+
forks: 1700+
open_pull_requests: 139
latest_github_release: Apache Ambari 3.0.0
latest_github_release_date: 2025-04-10
```

Evidence:

- https://github.com/apache/ambari

### 4.3 Ambari Scope Matches BIGDATA-1.0 Candidate Backend

Ambari README 明确其定位是用于 provisioning、managing、monitoring Apache Hadoop clusters，并提供 REST API 和浏览器管理界面。

这与 BIGDATA-1.0 的候选需求存在匹配：

```text
安装
配置
管理
监控
Hadoop 集群
```

Evidence:

- https://github.com/apache/ambari

## 5. Risks

### R-A101-001: Release Exists Does Not Equal Production Viability

Severity: Critical

Ambari 3.0.0 存在 ASF Release，但这只能证明存在发布包，不能证明它适合 BIGDATA-1.0 长期作为管理后端。

必须继续验证：

- Ubuntu 22.04 安装
- JDK 8 运行
- Ambari Server / Agent 稳定性
- Hadoop 3.5 管理能力
- Blueprint 能力

### R-A101-002: Component Compatibility Unknown

Severity: Critical

当前任务未验证 Ambari 3.0.0 是否支持：

- Hadoop 3.5.0
- Hive 4.x
- Spark 3.5.x
- HBase 2.5.x

该风险需要 TASK-104 和后续 Ambari Stack Compatibility 验证覆盖。

### R-A101-003: Community Activity Requires Deeper Quantitative Review

Severity: Medium

GitHub 页面能看到 Release、PR、提交总数等信号，但尚未完成近 6~12 个月提交频率、活跃维护者数量、Issue 响应速度等量化分析。

## 6. Recommendation

```yaml
result: CONDITIONAL_GO
reason:
  - Ambari 3.0.0 has ASF download presence.
  - Ambari 3.0.0 has GitHub release evidence.
  - Ambari project scope matches BIGDATA-1.0 backend candidate needs.
  - Production viability and Hadoop 3.5 compatibility are not yet proven.
next_action:
  - TASK-102 Ambari Ubuntu22 Validation
  - TASK-103 Ambari JDK8 Validation
  - TASK-104 Ambari Hadoop3.5 Compatibility Review
  - TASK-105 Ambari Blueprint Capability Review
```

## 7. Decision

Ambari 3.0.0 should remain in Sprint-1 validation as a candidate Backend Plugin.

It must not be treated as frozen BIGDATA-1.0 backend until TASK-102~TASK-105 produce evidence.
