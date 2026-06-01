# TASK-102 Ambari openEuler22 Validation Review

## 1. Metadata

```yaml
task: TASK-102
name: Ambari openEuler22 Validation Review
owner: Agent-A
sprint: Sprint-1
status: completed-initial-review
result: CONDITIONAL_GO
confidence: medium
```

## 2. Objective

根据 Sprint-1 执行中发现的公开证据，将 BIGDATA-1.0 RC1 的第一阶段 OS 验证方向从 Ubuntu 22.04 调整为 openEuler 22，并判断 Ambari + BIGTOP Stack 在 openEuler22 方向是否值得继续验证。

本任务不声明已经完成真实安装，只进行源码配置与公开仓库级别的初步验证。

## 3. Context Change

原始环境候选：

```yaml
os: Ubuntu 22.04
jdk: JDK 8
```

调整后 Sprint-1 环境候选：

```yaml
primary_os: openEuler 22
jdk: JDK 8
compatibility_os:
  - Ubuntu 22.04
```

调整原因：

- Ambari BIGTOP stack 仓库配置中明确出现 `openeuler22`。
- Ambari BIGTOP stack 当前示例未直接显示 Ubuntu 22.04 仓库配置。
- Bigtop 仓库中可以检索到 `config_openeuler-22.03.yaml`。

## 4. Findings

### 4.1 Ambari BIGTOP Stack Contains openEuler22 Repository Entry

Ambari 源码中的 BIGTOP 3.2.0 `repoinfo.xml` 包含：

```xml
<os family="openeuler22">
  <repo>
    <baseurl>https://bigtop-snapshot.s3.amazonaws.com/openeuler-22/$basearch</baseurl>
    <repoid>BIGTOP-3.2.0</repoid>
    <reponame>bigtop</reponame>
  </repo>
</os>
```

Evidence:

- `apache/ambari: ambari-server/src/main/resources/stacks/BIGTOP/3.2.0/repos/repoinfo.xml`

### 4.2 Ambari BIGTOP Stack Example Shows RedHat/openEuler Direction

The same Ambari BIGTOP stack repository configuration includes:

- redhat7
- redhat8
- redhat9
- openeuler22

No Ubuntu22 repository entry was found in this specific file during Sprint-1 review.

This does not prove Ubuntu22 is unsupported, but it means Ubuntu22 should not remain the primary Sprint-1 path without additional evidence.

### 4.3 Bigtop Repository Contains openEuler22 Docker Provisioner Config

Bigtop code search found:

```text
provisioner/docker/config_openeuler-22.03.yaml
```

This is an important positive signal for choosing openEuler22 as a validation target.

Evidence:

- `apache/bigtop: provisioner/docker/config_openeuler-22.03.yaml`

## 5. Risks

### R-A102-001: Ambari Stack Version Is BIGTOP 3.2.0, Not 3.5.0

Severity: High

Ambari BIGTOP stack repository sample references BIGTOP-3.2.0, while BIGDATA-1.0 currently evaluates Bigtop 3.5.0.

This means a repo definition update or custom stack adaptation may still be required.

### R-A102-002: openEuler22 Is Better Aligned Than Ubuntu22, But Not Yet Proven

Severity: High

The evidence supports switching validation direction, but it does not prove:

- Ambari Server installs successfully on openEuler22
- Ambari Agent registers successfully on openEuler22
- Bigtop 3.5.0 packages install successfully on openEuler22
- Hadoop/Hive/Spark services work through Ambari on openEuler22

### R-A102-003: Ubuntu22 Becomes Compatibility Target

Severity: Medium

Ubuntu22 should not be discarded permanently. It should move to compatibility evaluation after the primary RC1 route is validated.

## 6. Recommendation

```yaml
result: CONDITIONAL_GO
primary_os: openEuler22
compatibility_os:
  - Ubuntu22
reason:
  - Ambari BIGTOP stack has openeuler22 repository entry.
  - Bigtop repository has openEuler22 provisioner config.
  - Ubuntu22 direct evidence is weaker in current Ambari BIGTOP stack review.
next_action:
  - Adjust Sprint-1 TASK-102 from Ubuntu22 Validation to openEuler22 Validation.
  - Validate Ambari Server and Agent on openEuler22.
  - Validate Bigtop 3.5.0 package repository path for openEuler22.
  - Keep Ubuntu22 as later compatibility track.
```

## 7. Decision

Sprint-1 primary OS validation direction is adjusted to:

```yaml
primary_os: openEuler22
jdk: JDK8
```

Ubuntu22 is moved to compatibility evaluation and should not block Sprint-1 Gate-1.
