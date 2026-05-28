# 大数据组件版本矩阵

## 1. 目标

本文档用于记录 `bigdata` 项目中 Hadoop 生态组件的推荐版本组合，作为 Bigtop 构建、Ambari 安装和集成测试的共同基准。

## 2. 第一版推荐矩阵

> 当前为初始模板，实际版本需要根据目标发行版、操作系统、JDK 版本和 Ambari Stack 适配情况进一步确认。

| 组件 | 推荐版本 | 说明 |
|---|---:|---|
| Hadoop | 3.x | HDFS / YARN / MapReduce 基础组件 |
| ZooKeeper | 3.5+ / 3.6+ | 分布式协调服务 |
| Hive | 3.x | 数据仓库与 SQL 元数据服务 |
| Tez | 0.10+ | Hive on Tez 执行引擎 |
| Spark | 3.x | 离线计算与批处理引擎 |
| HBase | 2.x | 宽表存储 |
| Kafka | 2.x / 3.x | 消息队列与流式数据入口 |
| Ranger | 2.x | 权限与安全治理，后续补充 |
| Knox | 1.x | 网关与安全入口，后续补充 |
| Atlas | 2.x | 元数据与血缘治理，后续补充 |

## 3. 兼容性检查项

版本矩阵需要重点确认：

- JDK 版本兼容性
- Hadoop 与 Hive / Spark / HBase 的依赖兼容性
- Hive 与 Tez 的兼容性
- Kafka 客户端版本与服务端版本兼容性
- Ambari Stack 与组件包命名一致性
- 操作系统发行版与 RPM / DEB 包格式兼容性

## 4. 发布策略

建议每个可交付版本都记录：

```text
release-id: bigdata-stack-YYYYMMDD
os: rocky8 / centos7 / ubuntu22.04
jdk: 8 / 11
hadoop: x.y.z
hive: x.y.z
spark: x.y.z
ambari-stack: x.y
repo-url: http://repo.example.com/bigdata/...
```

## 5. 后续待办

- [ ] 明确目标 OS
- [ ] 明确目标 JDK
- [ ] 明确 Ambari Stack 版本
- [ ] 明确每个组件的实际构建版本
- [ ] 补充组件依赖关系图
- [ ] 补充版本升级策略
