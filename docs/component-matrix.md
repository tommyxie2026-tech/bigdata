# Bigdata Platform 组件矩阵

## 1. 文档目标

本文档用于定义 Bigdata Platform 的组件范围、阶段归属、管理方式、交付优先级和组合策略。

平台目标是同时支持传统数仓与实时数据湖，并允许组件按场景灵活组合交付。

## 2. 组件分层

```text
管理面：Ambari / Kubernetes / Operator
构建发行层：Bigtop / Package Repo / Version Matrix
存储层：HDFS / Object Storage
资源层：YARN / Kubernetes
计算层：Spark / Flink / MapReduce
SQL 层：Hive / Trino / Spark SQL
消息与接入层：Kafka / CDC Connector
湖仓层：Iceberg / Hudi / Delta Lake
治理安全层：Kerberos / Ranger / Knox / Atlas
运维观测层：Ambari Metrics / Prometheus / Logs / Alerting
```

## 3. 阶段组件矩阵

| 组件 | 类型 | Phase 1 传统数仓 | Phase 3 实时数据湖 | Phase 5 云原生 | 管理方式 | 优先级 |
|---|---|---|---|---|---|---|
| Ambari | 管理面 | 必选 | 可保留 | 部分保留 | Ambari Server | P0 |
| Bigtop | 构建发行 | 参考体系 | 参考体系 | 可替换 | Build/Repo | P0 |
| ZooKeeper | 协调服务 | 必选 | 必选 | 可 Operator 化 | Ambari / K8s | P0 |
| HDFS | 存储 | 必选 | 可选 | 部分保留 | Ambari | P0 |
| YARN | 资源管理 | 必选 | 可选 | 弱化 | Ambari | P0 |
| Hive Metastore | 元数据 | 必选 | 必选 | 可独立部署 | Ambari / K8s | P0 |
| HiveServer2 | SQL 服务 | 必选 | 可选 | 可替代 | Ambari | P0 |
| Spark | 批计算 | 必选 | 必选 | Spark on K8s | Ambari / K8s | P0 |
| Kafka | 消息队列 | 暂缓 | 必选 | Operator | Ambari/K8s | P1 |
| Flink | 流计算 | 暂缓 | 必选 | Operator | K8s 优先 | P1 |
| CDC Connector | 数据接入 | 暂缓 | 必选 | 容器化 | Flink/Kafka | P1 |
| Iceberg | 湖仓表格式 | 暂缓 | 推荐 | 推荐 | 元数据集成 | P1 |
| Hudi | 湖仓表格式 | 暂缓 | 可选 | 可选 | 元数据集成 | P2 |
| Delta Lake | 湖仓表格式 | 暂缓 | 可选 | 可选 | Spark 生态 | P2 |
| Trino | 查询引擎 | 暂缓 | 推荐 | 推荐 | K8s/独立部署 | P1 |
| HBase | 宽表存储 | 可选 | 可选 | 暂缓 | Ambari | P2 |
| Ranger | 权限治理 | 暂缓 | 推荐 | 推荐 | Ambari/独立 | P2 |
| Knox | 网关 | 暂缓 | 可选 | 可选 | Ambari/独立 | P3 |
| Atlas | 元数据治理 | 暂缓 | 可选 | 可选 | Ambari/独立 | P3 |
| Kubernetes | 运行平台 | 不要求 | 规划 | 必选 | K8s | P1 |
| Prometheus | 观测 | 可选 | 推荐 | 必选 | K8s/独立 | P2 |

## 4. 第一阶段核心组合

第一阶段聚焦传统数仓物理机底座。

```text
warehouse-basic:
  Ambari
  Bigtop Reference
  ZooKeeper
  HDFS
  YARN
  Hive Metastore
  HiveServer2
  Spark
```

### 4.1 第一阶段目标

- 完成 Hadoop 基础集群管理
- 支持离线数仓基础能力
- 支持 Spark 批处理
- 支持 Hive SQL 查询
- 支持 Ambari 统一管理、配置、监控和服务检查

### 4.2 第一阶段不纳入主线的组件

- Kafka
- Flink
- Iceberg / Hudi / Delta Lake
- Trino
- Ranger / Knox / Atlas
- Kubernetes / Operator

这些组件进入后续阶段，避免第一阶段失控。

## 5. 实时数据湖组合

第三阶段开始扩展实时数据湖能力。

```text
realtime-lakehouse:
  Kafka
  Flink
  CDC Connector
  Iceberg or Hudi
  Hive Metastore
  Trino or Spark SQL
  HDFS or Object Storage
```

### 5.1 关键能力

- 数据库变更捕获
- 消息队列缓冲
- 流式计算
- 湖仓表格式写入
- 元数据统一管理
- 近实时 SQL 查询
- 数据延迟与质量监控

## 6. 云原生组合

第五阶段开始支持容器平台和云原生数据组件。

```text
cloud-native-data:
  Kubernetes
  Spark Operator
  Flink Kubernetes Operator
  Kafka Operator
  Trino
  Object Storage
  Iceberg / Hudi
  Prometheus
```

## 7. 组件管理方式分类

| 管理方式 | 适合组件 | 说明 |
|---|---|---|
| Ambari | HDFS、YARN、Hive、Spark History、ZooKeeper | 适合传统 Hadoop 生态和物理机部署 |
| Bigtop | Hadoop、Hive、Spark 等包构建 | 适合版本矩阵、构建和包发行 |
| Kubernetes / Operator | Flink、Kafka、Spark、Trino | 适合云原生和弹性计算 |
| 独立服务 | Trino、Ranger、Atlas、Prometheus | 可根据场景独立部署 |

## 8. 组件扩展规范

每个新增组件必须补充：

- 组件定位
- 依赖组件
- 推荐版本
- 部署形态
- 管理方式
- 配置模板
- 安装流程
- 服务检查方式
- 监控指标
- 运维 runbook
- 与其他组件的兼容关系

## 9. 交付 Profile 规划

| Profile | 场景 | 组件组合 |
|---|---|---|
| warehouse-basic | 最小传统数仓 | HDFS + YARN + Hive + Spark + ZooKeeper |
| warehouse-ha | 高可用传统数仓 | warehouse-basic + HA 配置 + 多 Master |
| realtime-ingestion | 实时接入 | Kafka + Flink + CDC Connector |
| lakehouse-basic | 基础数据湖 | HDFS/Object Storage + Iceberg/Hudi + Hive Metastore |
| lakehouse-realtime | 实时数据湖 | Kafka + Flink + Iceberg/Hudi + Trino |
| governance-secure | 安全治理 | Kerberos + Ranger + Knox + Atlas |
| cloud-native-data | 云原生数据平台 | Kubernetes + Operators + Object Storage |

## 10. 后续待办

- [ ] 明确第一阶段组件具体版本
- [ ] 明确目标 OS 与 JDK 版本
- [ ] 明确 Hive / Spark / Hadoop 兼容关系
- [ ] 补充 Kafka / Flink / Iceberg 选型依据
- [ ] 补充组件依赖关系图
- [ ] 补充 Profile 交付模板
