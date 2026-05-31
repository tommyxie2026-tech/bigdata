# Bigdata Platform Validation Framework 设计

## 1. 文档目标

本文档定义 Bigdata Platform 的验证框架，用于证明 BIGDATA-1.0 候选版本、构建产物、安装流程、组件服务、HA 能力和 Release 交付物是否满足冻结和发布条件。

Validation Framework 是从架构设计走向真实交付的证据体系。

## 2. 背景

当前项目已经完成 Capability、Environment、Stack、Service Pack、Dependency Graph、Platform Core、Artifact Repository 和 Release 等核心设计。

但一个平台能否交付，不取决于文档是否完整，而取决于是否能通过可重复验证证明：

- 能构建
- 能安装
- 能启动
- 能管理
- 能通过 Smoke Test
- 能通过 HA 验证
- 能形成冻结版本
- 能回退

因此需要建立统一的 Validation Framework。

## 3. Validation Framework 定义

```text
Validation Framework = Validation Scope + Test Plan + Test Cases + Evidence + Defect Gate + Freeze Criteria
```

验证框架不只是测试脚本，而是一套从候选版本到 Release 冻结的决策机制。

## 4. 验证分层

BIGDATA-1.0 验证分为以下层级：

```text
V0: 文档与模型验证
V1: 构建验证
V2: 制品仓库验证
V3: 管理后端适配验证
V4: 单组件功能验证
V5: 集群集成验证
V6: HA 与故障切换验证
V7: 兼容性验证
V8: 回退验证
V9: Release 冻结验证
```

## 5. V0 文档与模型验证

验证对象：

- Capability Model
- Environment Model
- Stack Model
- Service Pack Model
- Dependency Graph
- Release Manifest

验收标准：

- 关键模型完整
- 组件依赖明确
- 版本矩阵明确
- 回退策略明确
- 验证计划和检查表存在

## 6. V1 构建验证

目标：验证 Bigtop 3.5.0 是否可构建 P0 组件 DEB 包。

范围：

| 组件 | 候选版本 | 验证项 |
|---|---:|---|
| Hadoop | 3.5.0 | DEB 构建、依赖完整性 |
| ZooKeeper | 3.9.5 | DEB 构建、systemd/service 适配 |
| Hive | 4.2.0 | HiveServer2、Metastore 构建 |
| Tez | 0.10.5 | Runtime 构建与 Hive 集成 |
| Spark | 3.5.8 | Spark on YARN 构建 |
| HBase | 2.5.14 | Master / RegionServer 构建 |

通过标准：

- 每个 P0 组件均有构建结论
- 构建产物可追踪
- 构建失败有缺陷记录和回退建议

## 7. V2 制品仓库验证

目标：验证构建产物能形成可被安装系统消费的仓库。

验证项：

- apt metadata 生成
- Ubuntu 22.04 节点 apt update 成功
- 目标包可查询
- 目标包可安装
- 仓库快照可保留
- 回退版本可并存

通过标准：

- Platform Repository 可用
- Customer Repository 可镜像
- Release Bundle 可以引用仓库快照

## 8. V3 管理后端适配验证

目标：验证 Ambari 3.0.0 能对接仓库并管理 P0 组件。

验证项：

- Ambari Server 安装
- Ambari Agent 注册
- Ambari Metrics 安装
- Repository 配置
- Blueprint 导入
- 服务安装、配置、启动、停止
- Service Check

通过标准：

- 7 节点 Agent 在线
- Ambari 可识别 Repository
- 核心服务可安装、配置、启停
- Service Check 可执行

## 9. V4 单组件功能验证

### 9.1 ZooKeeper

验证项：

- 3 节点集群状态
- 客户端连接
- 单节点停止后集群可用

### 9.2 HDFS

验证项：

- NameNode / DataNode / JournalNode 状态
- HDFS mkdir / put / cat / rm
- NameNode HA 状态

### 9.3 YARN

验证项：

- ResourceManager / NodeManager 状态
- YARN application 提交
- ResourceManager HA 状态

### 9.4 Hive

验证项：

- Metastore 启动
- HiveServer2 启动
- create database
- create table
- insert
- select
- join 基础查询

### 9.5 Spark

验证项：

- spark-submit
- Spark on YARN
- Spark SQL
- History Server
- 访问 Hive Metastore

### 9.6 HBase

验证项：

- HBase Master 状态
- RegionServer 状态
- create namespace
- create table
- put
- get
- scan
- drop table

## 10. V5 集群集成验证

目标拓扑：

```text
3 Master + 3 Worker + 1 Gateway
```

验证项：

- 所有节点 Agent 在线
- 所有核心服务启动
- Dashboard 状态正常
- Gateway Client 可用
- 跨组件功能可用

集成测试示例：

```text
HDFS -> Hive -> Spark SQL
HDFS -> HBase
Hive Metastore -> Spark SQL
YARN -> Spark Job
```

## 11. V6 HA 与故障切换验证

| 组件 | 验证项 |
|---|---|
| ZooKeeper | 停止 1 个节点后集群可用 |
| HDFS | NameNode Active/Standby 切换 |
| YARN | ResourceManager Active/Standby 切换 |
| Hive | HiveServer2 多实例可用 |
| Metastore | 多实例可用性 |
| HBase | HBase Master Failover |
| HBase RegionServer | RegionServer 异常后恢复 |

通过标准：

- 故障切换后核心能力可恢复
- 数据不丢失
- 服务状态可观察
- 有明确 Runbook

## 12. V7 兼容性验证

### 12.1 JDK 8 默认运行验证

每个 P0 组件必须给出 JDK 8 结论：

```text
Pass / Failed / Blocked / Not Applicable
```

### 12.2 JDK 17 兼容性评估

JDK 17 不作为 Phase 1 默认运行时，只作为未来升级评估。

验证项：

- 构建风险
- 启动风险
- 反射与模块化风险
- 依赖冲突风险
- Spark 4.1.x / HBase 2.6.5 升级路径

## 13. V8 回退验证

主候选失败时，需要验证回退路径。

| 组件 | 主候选 | 回退 |
|---|---:|---:|
| Ambari | 3.0.0 | 2.7.9 |
| Bigtop | 3.5.0 | 3.4.0 |
| Hadoop | 3.5.0 | 3.4.3 / 3.3.6 |
| ZooKeeper | 3.9.5 | 3.8.6 |
| Hive | 4.2.0 | 4.1.x / 3.x |
| Metastore | 4.2.0 | 3.0.0 |
| Tez | 0.10.5 | 0.10.4 / 0.10.3 |
| Spark | 3.5.8 | 3.4.x |
| HBase | 2.5.14 | 2.5.13 |

回退验证要求：

- 回退版本可构建
- 回退版本可安装
- 回退版本兼容 Stack
- 回退版本有验证结论

## 14. V9 Release 冻结验证

Release 冻结必须满足：

- V1 构建验证通过
- V2 仓库验证通过
- V3 管理适配验证通过
- V4 单组件功能验证通过
- V5 集群集成验证通过
- V6 HA 验证通过
- V7 JDK 8 结论明确
- V8 回退策略明确
- Blocker / Critical 缺陷清零
- Release Manifest 完整
- Validation Report 完整

## 15. 缺陷等级

| 等级 | 说明 | 是否阻断冻结 |
|---|---|---|
| Blocker | 阻断核心部署或核心能力 | 是 |
| Critical | 严重影响 HA、数据安全、核心服务 | 是 |
| Major | 影响重要功能但有规避 | 视情况 |
| Minor | 文档、体验、非核心问题 | 否 |

## 16. 证据模型

每个验证项都必须保留证据。

证据包括：

- 构建日志
- 包列表
- apt 仓库快照
- Ambari 安装记录
- Service Check 输出
- Smoke Test 输出
- HA 验证记录
- 缺陷记录
- 修复记录
- 验收结论

建议目录：

```text
validation/
├── builds/
├── repositories/
├── ambari/
├── smoke-tests/
├── ha/
├── compatibility/
├── defects/
└── reports/
```

## 17. Validation Report 模板

```text
Validation Report

1. Release Candidate:
2. Stack Version:
3. Environment Profile:
4. Validation Date:
5. Build Result:
6. Repository Result:
7. Ambari Adaptation Result:
8. Component Smoke Test Result:
9. HA Result:
10. Compatibility Result:
11. Defect Summary:
12. Freeze Decision:
13. Remaining Risks:
```

## 18. Agent 分工

| Agent | 职责 |
|---|---|
| Build Validation Agent | Bigtop 构建验证 |
| Repository Validation Agent | apt 仓库验证 |
| Ambari Validation Agent | 管理后端适配验证 |
| Component QA Agent | 单组件 Smoke Test |
| HA QA Agent | HA 和故障切换验证 |
| Compatibility Agent | JDK / OS / 版本兼容性 |
| Release Review Agent | 冻结评审 |

## 19. 与现有检查表关系

本框架汇总并约束以下检查表：

- `docs/checklists/p1-012-bigtop-build-validation-checklist.md`
- `docs/checklists/p1-013-ambari-adaptation-checklist.md`
- `docs/checklists/p1-014-jdk-compatibility-checklist.md`
- `docs/checklists/p1-015-3m3w1g-ha-validation-checklist.md`
- `docs/checklists/p1-016-version-freeze-review-checklist.md`

## 20. 当前不做事项

当前阶段不做：

- 完整自动化测试平台
- 完整 CI/CD 集群执行系统
- 自动化容量压测
- Chaos Engineering 自动化
- 性能基准测试体系

当前目标是先形成可执行、可记录、可评审的验证框架。

## 21. 后续工作

建议后续补：

- `validation/README.md`
- `validation/reports/BIGDATA-1.0.0-candidate-template.md`
- `scripts/smoke-tests/README.md`
- `docs/deployment-blueprint-design.md`
- `docs/backend-adapter-design.md`
- `docs/lifecycle-design.md`
