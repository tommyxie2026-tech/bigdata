# Bigdata Platform Artifact Repository 设计

## 1. 文档目标

本文档定义 Bigdata Platform 的 Artifact Repository 抽象、仓库分层、制品类型、版本状态、快照机制、离线交付、回滚策略和与 Stack、Service Pack、Blueprint、Release 的关系。

Artifact Repository 不只是软件包仓库，而是平台所有可交付制品的统一管理体系。

## 2. 设计背景

如果平台只管理 apt/yum 软件包，会导致以下问题：

- 只能管理组件包，不能管理 Stack 版本矩阵
- 不能统一管理 Blueprint、配置、Runbook、Smoke Test
- 离线交付缺少完整交付单元
- 回滚只能回滚包，不能回滚部署模板和配置
- 未来容器、Operator、Helm Chart、对象存储配置无法统一纳管

因此平台需要的是 Artifact Repository，而不是单一 Package Repository。

## 3. Artifact Repository 定义

Artifact Repository 用于管理 Bigdata Platform 的全部交付制品。

```text
Artifact Repository
  ├── Package Repository
  ├── Stack Repository
  ├── Service Pack Repository
  ├── Blueprint Repository
  ├── Config Repository
  ├── Runbook Repository
  ├── Check Repository
  ├── Bundle Repository
  └── Release Repository
```

## 4. 制品类型

| 制品类型 | 说明 | 示例 |
|---|---|---|
| Package | 组件软件包 | deb、rpm、tar.gz、jar |
| Stack | 平台版本矩阵 | BIGDATA-1.0 |
| Service Pack | 组件管理规范 | hdfs、yarn、hive、spark |
| Blueprint | 部署拓扑模板 | 3m3w1g-ha、single-node |
| Config | 配置模板 | core-site.xml、hdfs-site.xml、hive-site.xml |
| Runbook | 运维手册 | install、restart、recovery |
| Check | 检查脚本或检查定义 | smoke test、service check |
| Bundle | 离线交付包 | BIGDATA-1.0-HA-offline-bundle |
| Release | 可交付发布版本 | BIGDATA-1.0.0 |

## 5. 仓库分层

### 5.1 Source Repository

来源仓库。

```text
Apache Release
GitHub Source
Internal Patch Source
```

用途：

- 获取上游源码
- 记录上游版本
- 记录补丁来源

### 5.2 Build Repository

构建输出仓库。

```text
Bigtop Build Output
Internal Build Output
```

用途：

- 保存构建出的 deb/rpm/tar.gz/jar
- 保存构建日志
- 保存构建元数据

### 5.3 Platform Repository

平台正式仓库。

```text
BIGDATA-1.0 candidate repo
BIGDATA-1.0 validated repo
BIGDATA-1.0 frozen repo
```

用途：

- 平台版本验证
- Ambari Repository 对接
- 在线安装
- 版本冻结

### 5.4 Customer Repository

客户环境仓库。

```text
Customer Online Repo
Customer Offline Repo
Customer Mirror Repo
```

用途：

- 私有化交付
- 离线部署
- 客户侧升级与回滚

## 6. Package Repository

Package Repository 负责管理组件包。

BIGDATA-1.0 包类型：

```text
DEB / apt
```

未来可能支持：

```text
RPM / yum
tar.gz
jar
container image
helm chart
operator bundle
```

BIGDATA-1.0 示例：

| 组件 | 包来源 | 包类型 |
|---|---|---|
| Hadoop | Bigtop | deb |
| ZooKeeper | Bigtop | deb |
| Hive | Bigtop | deb |
| Spark | Bigtop | deb |
| HBase | Bigtop | deb |

## 7. Stack Repository

Stack Repository 负责管理平台版本矩阵。

示例：

```yaml
stack: BIGDATA-1.0
status: candidate
components:
  hadoop: 3.5.0
  zookeeper: 3.9.5
  hive: 4.2.0
  spark: 3.5.8
  hbase: 2.5.14
```

Stack Repository 必须记录：

- Stack 名称
- Stack 版本
- 组件版本
- 状态
- 兼容性验证结果
- 回退版本
- 冻结时间

## 8. Service Pack Repository

Service Pack Repository 管理组件接入规范。

```text
service-packs/
├── hdfs/
├── yarn/
├── zookeeper/
├── hive/
├── spark/
└── hbase/
```

它与 Package Repository 的关系是：

```text
Service Pack declares packages
Package Repository provides packages
```

## 9. Blueprint Repository

Blueprint Repository 管理部署拓扑模板。

示例：

```text
blueprints/
├── single-node/
├── 3m3w1g-ha/
├── production-ha/
└── gateway-only/
```

Blueprint 必须与 Stack 和 Service Pack 对齐。

## 10. Config Repository

Config Repository 管理配置模板与环境覆盖。

建议分层：

```text
configs/
├── defaults/
├── profiles/
├── environments/
└── customer-overrides/
```

配置必须支持：

- 版本化
- 审计
- 差异对比
- 回滚
- Profile 覆盖
- 客户化覆盖

## 11. Bundle Repository

Bundle 是私有化交付的核心单元。

一个 Bundle 应包含：

```text
BIGDATA-1.0-HA-offline-bundle/
├── packages/
├── stack/
├── service-packs/
├── blueprints/
├── configs/
├── runbooks/
├── checks/
├── manifests/
└── README.md
```

Bundle 用于：

- 离线安装
- 客户交付
- 版本归档
- 审计追踪
- 灾备恢复

## 12. Release Repository

Release 是正式交付版本。

Release 应记录：

- Release 版本号
- Stack 版本
- Bundle 版本
- 包仓库快照
- Blueprint 列表
- 配置模板版本
- Runbook 版本
- 验证报告
- 已知问题
- 回滚版本

示例：

```text
BIGDATA-1.0.0
BIGDATA-1.0.1
BIGDATA-2.0.0
```

## 13. 制品状态模型

制品状态建议统一为：

```text
candidate
validated
frozen
deprecated
rejected
```

| 状态 | 说明 |
|---|---|
| candidate | 候选制品，已进入验证 |
| validated | 验证通过，但尚未冻结 |
| frozen | 已冻结，可作为发布基线 |
| deprecated | 已废弃，不建议新部署 |
| rejected | 验证失败，不进入发布 |

## 14. 快照机制

每次验证或发布应形成快照。

示例：

```text
BIGDATA-1.0-candidate-20260601
BIGDATA-1.0-validated-20260615
BIGDATA-1.0-frozen-20260630
```

快照必须包含：

- 包版本
- 配置版本
- Blueprint 版本
- Service Pack 版本
- Runbook 版本
- 验证结果

## 15. 回滚机制

回滚不能只回滚包，还必须回滚：

- Stack 版本矩阵
- Package Repository 快照
- Blueprint
- Config
- Service Pack
- Runbook
- Smoke Test

回滚目标：

```text
Release N -> Release N-1
```

或：

```text
Snapshot X -> Snapshot Y
```

## 16. 在线与离线交付

### 16.1 在线交付

```text
Platform Repository
  -> Ambari Repository Config
  -> Cluster Install
```

### 16.2 离线交付

```text
Bundle
  -> Customer Repository
  -> Ambari Repository Config
  -> Cluster Install
```

两种方式必须使用同一套 Stack、Service Pack、Blueprint 和 Config。

## 17. 与 Ambari 的关系

Ambari 消费的是 Artifact Repository 中的一部分：

- Package Repository
- Repository Config
- Blueprint
- Config
- Service Check

但 Artifact Repository 不应绑定 Ambari。未来 Kubernetes / Operator 也应复用同一套制品模型。

## 18. BIGDATA-1.0 Artifact 范围

BIGDATA-1.0 至少需要管理：

- Ubuntu 22.04 DEB 包
- apt 仓库
- BIGDATA-1.0 Stack 元数据
- HDFS / YARN / Hive / Spark / HBase Service Pack
- 3M3W1G HA Blueprint
- 默认配置模板
- Runbook
- Smoke Test
- 验证检查表
- 离线 Bundle 设计

## 19. 当前不做事项

当前阶段不做：

- 完整制品仓库服务实现
- Web UI
- 自动制品发布流水线
- 容器镜像仓库实现
- Helm / Operator Bundle 实现

当前目标是先固化 Artifact Repository 模型。

## 20. 后续文档

建议继续补：

- `docs/release-design.md`
- `docs/blueprint-design.md`
- `docs/lifecycle-design.md`
- `docs/management-backend-design.md`
