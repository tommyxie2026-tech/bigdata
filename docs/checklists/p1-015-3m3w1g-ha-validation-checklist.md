# P1-015 3M3W1G 集群与 HA 验证检查表

## 1. 检查表目标

本文档用于执行 P1-015：基于 3 Master + 3 Worker + 1 Gateway 拓扑验证 Phase 1 候选版本组合的集群部署、服务可用性、HA 和 Smoke Test。

## 2. 验证拓扑

```text
master-01
master-02
master-03
worker-01
worker-02
worker-03
gateway-01
```

## 3. 节点角色检查

| 节点 | 角色 | 检查结果 | 备注 |
|---|---|---|---|
| master-01 | Ambari Server、NameNode、ResourceManager、Hive、HBase Master、ZooKeeper | TODO |  |
| master-02 | Standby NameNode、Standby ResourceManager、Hive、HBase Master、ZooKeeper | TODO |  |
| master-03 | JournalNode、ZooKeeper、Spark History Server、Hive/HBase 备选 | TODO |  |
| worker-01 | DataNode、NodeManager、HBase RegionServer | TODO |  |
| worker-02 | DataNode、NodeManager、HBase RegionServer | TODO |  |
| worker-03 | DataNode、NodeManager、HBase RegionServer | TODO |  |
| gateway-01 | Hadoop Client、Hive Client、Spark Client、HBase Client、运维入口 | TODO |  |

## 4. 基础环境检查

| 编号 | 检查项 | 结果 | 备注 |
|---|---|---|---|
| ENV-001 | Ubuntu 22.04 | TODO |  |
| ENV-002 | JDK 8 | TODO |  |
| ENV-003 | 主机名解析 | TODO |  |
| ENV-004 | 时间同步 | TODO |  |
| ENV-005 | SSH 连通性 | TODO |  |
| ENV-006 | 磁盘目录 | TODO |  |
| ENV-007 | 防火墙/端口策略 | TODO |  |
| ENV-008 | Ambari Agent 在线 | TODO |  |

## 5. 服务安装检查

| 编号 | 服务 | 安装结果 | 启动结果 | Ambari 状态 | 备注 |
|---|---|---|---|---|---|
| INSTALL-001 | ZooKeeper | TODO | TODO | TODO |  |
| INSTALL-002 | HDFS | TODO | TODO | TODO |  |
| INSTALL-003 | YARN | TODO | TODO | TODO |  |
| INSTALL-004 | Hive | TODO | TODO | TODO |  |
| INSTALL-005 | Tez | TODO | TODO | TODO |  |
| INSTALL-006 | Spark | TODO | TODO | TODO |  |
| INSTALL-007 | HBase | TODO | TODO | TODO |  |

## 6. Service Check

| 编号 | 服务 | Service Check | 失败原因 | 处理建议 |
|---|---|---|---|---|
| CHECK-001 | ZooKeeper | TODO |  |  |
| CHECK-002 | HDFS | TODO |  |  |
| CHECK-003 | YARN | TODO |  |  |
| CHECK-004 | Hive | TODO |  |  |
| CHECK-005 | Spark | TODO |  |  |
| CHECK-006 | HBase | TODO |  |  |

## 7. Smoke Test

| 编号 | 组件 | 测试内容 | 结果 | 备注 |
|---|---|---|---|---|
| SMOKE-001 | HDFS | mkdir / put / cat / rm | TODO |  |
| SMOKE-002 | YARN | node list / application submit | TODO |  |
| SMOKE-003 | Hive | create database / create table / insert / select | TODO |  |
| SMOKE-004 | Spark | spark-submit / Spark SQL / History Server | TODO |  |
| SMOKE-005 | HBase | create namespace / create table / put / get / scan / drop | TODO |  |

## 8. HA 验证

| 编号 | 组件 | 验证内容 | 结果 | 备注 |
|---|---|---|---|---|
| HA-001 | ZooKeeper | 停止 1 个 ZooKeeper 节点，集群保持可用 | TODO |  |
| HA-002 | HDFS | NameNode Active / Standby 状态正常 | TODO |  |
| HA-003 | HDFS | 手动 NameNode Failover | TODO |  |
| HA-004 | YARN | ResourceManager Active / Standby 状态正常 | TODO |  |
| HA-005 | YARN | 手动 ResourceManager Failover | TODO |  |
| HA-006 | Hive | HiveServer2 多实例可用 | TODO |  |
| HA-007 | Hive | Metastore 多实例可用 | TODO |  |
| HA-008 | HBase | HBase Master Active / Standby 状态正常 | TODO |  |
| HA-009 | HBase | HBase Master Failover | TODO |  |
| HA-010 | HBase | RegionServer 异常后 Region 恢复 | TODO |  |

## 9. Gateway 验证

| 编号 | 检查项 | 结果 | 备注 |
|---|---|---|---|
| GW-001 | HDFS Client 可用 | TODO |  |
| GW-002 | YARN Client 可用 | TODO |  |
| GW-003 | Hive Client 可用 | TODO |  |
| GW-004 | Spark Client 可用 | TODO |  |
| GW-005 | HBase Client 可用 | TODO |  |
| GW-006 | 运维脚本入口可用 | TODO |  |

## 10. 缺陷记录模板

| 缺陷编号 | 组件 | 严重级别 | 描述 | 影响 | 处理建议 | 状态 |
|---|---|---|---|---|---|---|
| BUG-001 | TBD | TBD | TBD | TBD | TBD | OPEN |

## 11. 输出结论

| 结论项 | 结果 |
|---|---|
| 3M3W1G 集群是否部署成功 | TODO |
| 核心服务是否全部启动 | TODO |
| Service Check 是否通过 | TODO |
| Smoke Test 是否通过 | TODO |
| HA 验证是否通过 | TODO |
| 是否可以进入版本冻结评审 | TODO |

## 12. 关联文档

- `docs/phase1-ha-design.md`
- `docs/phase1-test-plan.md`
- `docs/phase1-version-validation-plan.md`
- `docs/phase1-acceptance-criteria.md`
