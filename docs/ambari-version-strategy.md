# Ambari 版本策略

## 1. 文档目标

本文档定义 Bigdata Platform 第一阶段 Ambari 版本选择、兼容性验证、维护策略和后续演进路线。

第一阶段已确认：优先使用最新可维护的社区/发行版最新兼容版本。

## 2. Ambari 定位

Ambari 是 Bigdata Platform 在传统 Hadoop、物理机和虚拟机部署形态下的长期管理面。

Ambari 负责：

- 主机注册
- 组件安装
- Repository 配置
- 服务配置下发
- 服务启停
- HA 配置管理
- Service Check
- 监控告警
- 运维入口

## 3. 版本选择原则

### 3.1 可维护性优先

优先选择仍可维护、可修复、可适配 Ubuntu 22.04 的 Ambari 版本或发行版兼容版本。

### 3.2 兼容性优先

Ambari 版本必须兼容：

- Ubuntu 22.04
- JDK 8
- Bigtop 构建出的组件包
- Hadoop / HDFS / YARN
- Hive
- Spark
- HBase
- ZooKeeper

### 3.3 工程可控

版本选择不能只看版本号新旧，还需要确认：

- 安装包可获得
- 依赖可满足
- Agent 可正常运行
- Repository 配置可接入
- Blueprint 可执行
- Service Check 可运行

## 4. 候选来源

| 来源 | 说明 | 风险 |
|---|---|---|
| Apache Ambari 社区版本 | 上游社区版本，透明度高 | 维护活跃度和现代 OS 兼容性需验证 |
| 发行版兼容版本 | 可能已有补丁和集成经验 | 可能与特定发行版绑定 |
| 自维护构建版本 | 可控性最高 | 维护成本最高 |

第一阶段优先顺序：

```text
最新可维护社区/发行版兼容版本
  -> 必要补丁适配
  -> 自维护构建，作为备选
```

## 5. Ubuntu 22.04 验证项

Ambari 候选版本必须在 Ubuntu 22.04 上验证：

- Ambari Server 安装
- Ambari Agent 安装
- Python / systemd / OS 依赖
- 数据库依赖
- Agent 心跳
- Web UI 可访问
- REST API 可访问
- Repository 配置
- Blueprint 创建集群

## 6. JDK 验证项

### 6.1 JDK 8

JDK 8 是第一阶段默认基线，必须完整验证。

### 6.2 JDK 17

JDK 17 作为兼容性评估，不作为第一阶段默认运行时。

评估重点：

- Ambari Server 启动兼容性
- Ambari Agent 脚本兼容性
- Hadoop / Hive / Spark / HBase 服务运行兼容性
- 依赖库和反射访问问题

## 7. 与 Bigtop 的关系

Ambari 消费 Bigtop 产出的包仓库。

需要保证：

- 包名与 Ambari 服务定义一致
- Repository base url 可配置
- 组件安装命令与 Ubuntu 22.04 apt 包体系匹配
- Service Check 与组件实际安装路径匹配

## 8. 与自定义 Stack 的关系

自定义 Ambari Stack 已确认放入远期规划，不进入第一阶段主线。

第一阶段优先使用：

- 可用 Stack
- Blueprint
- Repository 配置
- 配置模板
- Runbook

避免过早进入完整 Stack 维护。

## 9. 版本决策流程

```text
收集 Ambari 候选版本
  -> Ubuntu 22.04 安装验证
  -> JDK 8 运行验证
  -> Bigtop Repo 对接验证
  -> 3M3W1G Blueprint 验证
  -> Service Check 验证
  -> JDK 17 兼容性评估
  -> 冻结 Ambari 版本
```

## 10. 验收标准

Ambari 版本进入 Phase 1 基线必须满足：

- 可在 Ubuntu 22.04 安装
- 可使用 JDK 8 运行
- Server / Agent 正常通信
- 可配置 Bigtop apt 仓库
- 可安装 HDFS / YARN / Hive / Spark / HBase
- 可执行 Service Check
- 可支撑 3 Master + 3 Worker + 1 Gateway 验证拓扑

## 11. 后续待办

- [ ] 收集 Ambari 候选版本
- [ ] 验证 Ubuntu 22.04 安装路径
- [ ] 验证 JDK 8 运行兼容性
- [ ] 验证 JDK 17 兼容性
- [ ] 验证 Bigtop apt 仓库对接
- [ ] 冻结 Ambari 版本策略
