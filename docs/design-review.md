# Bigdata Platform 设计评审与待确认问题

## 1. 文档目标

本文档用于对当前 Bigdata Platform 的设计文档进行阶段性评审，明确已经达成共识的内容、仍不明确的问题、需要决策的事项、风险点和下一步修订计划。

当前平台目标是建设一套同时支持传统数仓和实时数据湖的大数据平台，能够在物理机、虚拟机和远期容器平台上运行，并支持大数据组件自定义扩展、灵活组合交付。

## 2. 已确认的设计共识

### 2.1 平台总体定位

Bigdata Platform 不是单一 Hadoop 集群，也不是单一实时计算平台，而是一套可演进的大数据平台方案。

平台需要同时支持：

- 传统离线数仓
- 实时数据湖
- 物理机部署
- 虚拟机部署
- 远期容器平台部署
- 组件可插拔
- 组件自定义扩展
- 组合式交付

### 2.2 阶段节奏

当前阶段应聚焦设计规划，不继续深入工程脚本、Ambari Service Script 或自定义 Stack 的生产化实现。

当前优先级：

```text
平台定位 -> 架构设计 -> 组件矩阵 -> 部署设计 -> 运维设计 -> 实时数据湖设计 -> Agent 拆分 -> Review 收敛
```

### 2.3 第一阶段方向

第一阶段以传统数仓物理机底座为主，优先使用 Ambari 管理 Hadoop 生态组件。

第一阶段核心组件暂定：

- Ambari
- Bigtop 参考体系
- ZooKeeper
- HDFS
- YARN
- Hive Metastore
- HiveServer2
- Spark

### 2.4 后续演进方向

后续阶段逐步扩展：

- 实时数据湖：Kafka、Flink、CDC、Iceberg/Hudi、Trino
- 虚拟机交付：多环境、镜像化、自动化初始化
- 容器平台：Kubernetes、Operator、对象存储、云原生观测
- 组合交付：Profile、组件市场、扩展规范

## 3. 当前文档体系

当前已形成以下核心设计文档：

| 文档 | 作用 |
|---|---|
| `platform-overview.md` | 平台总览与定位 |
| `roadmap.md` | 阶段路线图与任务拆分 |
| `technical-design.md` | 总体技术设计 |
| `deployment-design.md` | 部署设计 |
| `component-matrix.md` | 组件矩阵 |
| `operations-design.md` | 运维体系设计 |
| `realtime-lakehouse-design.md` | 实时数据湖设计 |
| `agent-execution-plan.md` | 并行 Agent 执行计划 |
| `ambari-management-plane.md` | Ambari 管理面设计 |
| `ambari-bigtop-integration.md` | Ambari + Bigtop 集成设计 |
| `ambari-stack-design.md` | 自定义 Ambari Stack 远期设计 |

## 4. 需要确认的问题清单

以下问题需要进一步确认，否则会影响后续设计与工程阶段的边界。

## 5. 平台定位类问题

### Q1：第一版产品形态是什么？

当前有几种可能：

| 选项 | 说明 |
|---|---|
| A | 大数据平台设计文档与工程资产仓库 |
| B | 可部署的私有化大数据平台方案 |
| C | 企业级大数据发行版 |
| D | 面向内部研发的统一数据平台底座 |

建议确认：第一版是否定位为 **可部署的私有化大数据平台方案**，而不是完整商业产品。

### Q2：第一阶段主要面向谁交付？

需要确认目标用户：

- 内部研发团队
- 运维团队
- 私有化交付团队
- 企业客户
- 学习/实验环境

不同用户会影响文档深度、自动化程度、验收标准和安全要求。

### Q3：平台名称是否确定为 Bigdata Platform？

当前文档统一使用 `Bigdata Platform`。需要确认是否保持该名称，还是后续另起产品名。

## 6. 第一阶段范围类问题

### Q4：第一阶段是否只做传统数仓？

当前建议第一阶段聚焦传统数仓物理机底座。

需要确认是否严格排除：

- Kafka
- Flink
- Iceberg / Hudi
- Trino
- Kubernetes

建议：第一阶段可以保留这些作为路线图，但不进入主线交付。

### Q5：第一阶段是否必须实现高可用？

当前文档包含最小验证集群和生产推荐集群，但还没有确定第一阶段交付是否必须支持 HA。

需要确认：

| 选项 | 说明 |
|---|---|
| A | 只支持最小验证集群 |
| B | 支持非 HA 生产参考集群 |
| C | 支持 HA 生产推荐拓扑 |

建议：第一阶段设计文档支持 HA 拓扑，但工程验证先做最小集群。

### Q6：第一阶段 Spark 是只作为批处理，还是也承担 SQL 查询？

需要确认 Spark 的定位：

- 批处理引擎
- Spark SQL 查询引擎
- 机器学习工作负载引擎
- 未来实时处理补充

建议：第一阶段 Spark 主要定位为批处理和离线 SQL 补充。

## 7. Ambari 相关问题

### Q7：Ambari 是长期管理面还是第一阶段管理面？

当前设计中 Ambari 是第一阶段管理面。

需要确认它是否长期承担所有部署形态下的管理职责，还是只负责传统 Hadoop 物理机 / 虚拟机部署。

建议：Ambari 作为传统 Hadoop 管理面；云原生阶段由 Kubernetes / Operator 管理。

### Q8：是否真的要维护自定义 Ambari Stack？

当前已经有 `ambari-stack-design.md` 和部分 Stack 骨架，但这条路很重。

需要确认：

| 选项 | 说明 |
|---|---|
| A | 不维护自定义 Stack，只使用现有 Stack / Blueprint / 配置模板 |
| B | 远期维护自定义 BIGDATA Stack |
| C | 第一阶段就实现自定义 Stack |

建议：选择 B，把自定义 Stack 放到远期，不作为第一阶段主线。

### Q9：Ambari 版本与生态兼容策略是什么？

需要确认：

- 使用 Apache Ambari 社区版本？
- 使用已有发行版中的 Ambari？
- 是否需要适配 HDP 生态？
- 是否需要自行维护 Ambari 构建？

该问题会影响 Bigtop、Stack、服务定义和安装流程。

## 8. Bigtop 相关问题

### Q10：Bigtop 是真实构建体系，还是参考体系？

当前文档把 Bigtop 定义为组件构建、版本矩阵和包发行参考体系。

需要确认：

| 选项 | 说明 |
|---|---|
| A | 仅作为设计参考，不实际构建 |
| B | 使用 Bigtop 构建部分组件包 |
| C | 基于 Bigtop 建设完整发行体系 |

建议：第一阶段选择 A/B 之间，先作为参考体系，并验证部分构建链路。

### Q11：目标操作系统是什么？

需要明确第一阶段目标 OS：

- CentOS 7
- Rocky Linux 8/9
- Ubuntu 22.04/24.04
- openEuler
- 多 OS

建议：第一阶段只选一个主 OS，避免版本矩阵过大。

### Q12：目标 JDK 版本是什么？

需要确认：

- JDK 8
- JDK 11
- JDK 17

Hadoop、Hive、Spark、Ambari、Bigtop 的兼容性会受 JDK 版本影响。

建议：第一阶段优先选择 JDK 8 或 JDK 11，根据组件版本矩阵最终确认。

## 9. 实时数据湖相关问题

### Q13：实时数据湖默认表格式选哪个？

候选：

| 选项 | 说明 |
|---|---|
| Iceberg | 流批统一、多引擎、Schema 演进能力强 |
| Hudi | CDC/upsert 场景友好，实时写入能力强 |
| Delta Lake | Spark 生态较强，但多引擎和开源生态需评估 |

建议：默认设计以 Iceberg 为主，Hudi 作为可选 Profile。

### Q14：实时计算默认使用 Flink 还是 Spark Streaming？

候选：

- Flink 作为实时主引擎
- Spark Structured Streaming 作为补充
- 两者都支持，按 Profile 选择

建议：第三阶段以 Flink 为实时主引擎，Spark 保留为批处理和流批一体补充。

### Q15：实时链路是否必须支持 CDC？

如果实时数据湖目标明确，CDC 很可能是核心能力。

需要确认第一批数据源：

- MySQL
- PostgreSQL
- Oracle
- SQL Server
- 日志系统
- Kafka 现有 Topic

建议：第三阶段优先支持 MySQL/PostgreSQL CDC。

### Q16：对象存储是否进入实时数据湖主线？

实时数据湖通常更适合对象存储 + 表格式。

需要确认：

- 第一阶段只使用 HDFS
- 第三阶段引入对象存储
- 是否需要支持 S3 兼容存储

建议：第一阶段 HDFS，第三阶段支持 S3 兼容对象存储。

## 10. 虚拟机与容器平台问题

### Q17：虚拟机阶段的目标是什么？

需要明确 VM 阶段是为了：

- 多环境复制
- 私有化交付
- 资源隔离
- 自动化测试
- 替代物理机生产部署

建议：Phase 4 以多环境交付和私有化复制为目标。

### Q18：容器平台阶段是否以 Kubernetes 为唯一目标？

需要确认是否支持：

- Kubernetes
- OpenShift
- Rancher
- 私有云 K8s
- 公有云托管 K8s

建议：文档层面定义 Kubernetes 通用模型，适配层再考虑 OpenShift/Rancher。

### Q19：哪些组件未来迁移到 Kubernetes？

需要明确边界：

| 组件 | 建议管理方式 |
|---|---|
| HDFS | 继续 Ambari / 传统部署 |
| YARN | 继续 Ambari / 可逐步弱化 |
| Hive Metastore | 可独立部署 / K8s 化 |
| Spark | Spark on Kubernetes |
| Flink | Flink Kubernetes Operator |
| Kafka | Kafka Operator |
| Trino | Kubernetes 部署 |
| Iceberg/Hudi | 与对象存储和计算引擎集成 |

## 11. 安全治理问题

### Q20：第一阶段是否纳入 Kerberos？

Kerberos 对传统 Hadoop 生产环境很重要，但会显著增加复杂度。

建议：第一阶段设计保留安全章节，工程验证可先不启用 Kerberos。

### Q21：Ranger / Knox / Atlas 进入哪个阶段？

建议：

- Ranger：Phase 2/3 进入设计
- Knox：Phase 3/4 可选
- Atlas：Phase 3/6 可选

需要确认安全治理是否是近期刚需。

## 12. 交付与产品化问题

### Q22：是否需要定义交付 Profile？

当前建议定义：

- warehouse-basic
- warehouse-ha
- realtime-ingestion
- lakehouse-basic
- lakehouse-realtime
- governance-secure
- cloud-native-data

需要确认这些 Profile 是否符合你的产品化思路。

### Q23：是否需要平台控制台？

当前设计使用 Ambari 作为第一阶段管理面。

需要确认远期是否需要自研统一控制台，覆盖：

- 组件选择
- 集群部署
- 作业管理
- 监控告警
- 数据湖治理
- 多环境交付

建议：远期可以规划，但不进入当前设计主线。

### Q24：交付对象是源码、文档、安装包，还是完整平台发行版？

需要确认最终交付形态：

| 交付形态 | 说明 |
|---|---|
| 文档 + 模板 | 轻量，适合早期 |
| 脚本 + 配置 | 可验证，适合内部交付 |
| 安装包 + Repo | 可复制，适合私有化交付 |
| 平台发行版 | 产品化程度最高，成本也最高 |

建议分阶段推进，不一开始做完整发行版。

## 13. Agent 执行问题

### Q25：是否真的采用并行 Agent 工作流？

如果采用，需要确认：

- Agent 输出是否直接提交仓库？
- 是否需要 Review Agent 统一审核？
- 是否按 Issue 拆任务？
- 是否按 PR 合并？

建议：设计阶段可以采用 Agent 分工，工程阶段必须走 PR Review。

### Q26：Agent 的第一批任务如何拆？

建议第一批：

| Agent | 任务 |
|---|---|
| Architecture Agent | 修订总体架构和平台总览 |
| Component Agent | 细化组件矩阵和版本选择 |
| Deployment Agent | 细化物理机部署和 HA 拓扑 |
| Operations Agent | 细化运维手册和告警指标 |
| Realtime Lakehouse Agent | 细化实时数据湖边界 |
| Review Agent | 统一审查所有设计文档 |

## 14. 关键决策建议

以下是建议优先拍板的决策项。

| 编号 | 决策项 | 建议值 | 优先级 |
|---|---|---|---|
| D1 | 第一版产品形态 | 可部署的私有化大数据平台方案 | P0 |
| D2 | 第一阶段范围 | 传统数仓物理机底座 | P0 |
| D3 | 第一阶段组件 | Ambari + HDFS + YARN + Hive + Spark + ZooKeeper | P0 |
| D4 | Ambari 定位 | 传统 Hadoop 管理面 | P0 |
| D5 | Bigtop 定位 | 构建与发行参考体系，逐步验证 | P0 |
| D6 | 自定义 Stack | 远期规划，不进入第一阶段主线 | P0 |
| D7 | 实时数据湖默认表格式 | Iceberg 主线，Hudi 可选 | P1 |
| D8 | 实时计算引擎 | Flink 主线，Spark 补充 | P1 |
| D9 | 容器平台 | Kubernetes 通用模型 | P1 |
| D10 | 安全治理 | 第一阶段保留设计，不强制落地 | P1 |

## 15. 当前风险

| 风险 | 说明 | 建议 |
|---|---|---|
| 范围过大 | 同时覆盖数仓、湖仓、实时、云原生，容易失控 | 严格按阶段推进 |
| Ambari 生态陈旧 | Ambari 与现代组件生态存在兼容风险 | 第一阶段限定传统 Hadoop |
| Bigtop 成本高 | 完整发行体系成本较高 | 初期作为参考体系 |
| 自定义 Stack 太重 | 维护成本高 | 放入远期规划 |
| 实时数据湖复杂 | CDC、Flink、Iceberg、Trino 组合复杂 | 第三阶段专项设计 |
| 云原生迁移风险 | Hadoop 与 Kubernetes 管理模型不同 | 采用混合管理面 |

## 16. 下一步建议

建议下一步不是继续扩展新文档，而是对上述问题逐项确认。

确认后执行：

1. 更新 `platform-overview.md`
2. 更新 `roadmap.md`
3. 更新 `component-matrix.md`
4. 更新 `deployment-design.md`
5. 将不进入第一阶段的内容标记为 Roadmap
6. 开始拆 Phase 1 的详细设计任务

## 17. 待确认问题汇总

请优先确认以下 10 个问题：

1. 第一版产品形态是否是“可部署的私有化大数据平台方案”？
2. 第一阶段是否严格聚焦“传统数仓物理机底座”？
3. 第一阶段是否只包含 Ambari、ZooKeeper、HDFS、YARN、Hive、Spark？
4. 第一阶段是否只设计 HA，不强制先实现 HA？
5. Ambari 是否仅作为传统 Hadoop 管理面，而不是长期统一管理面？
6. Bigtop 是参考体系，还是第一阶段就要真实构建组件包？
7. 自定义 Ambari Stack 是否放到远期？
8. 实时数据湖是否以 Iceberg + Flink 为主线？
9. 第三阶段是否引入 S3 兼容对象存储？
10. 是否采用 Agent + Review 的并行工作流来推进后续设计？
