# P1-013 Ambari 3.0.0 管理适配检查表

## 1. 检查表目标

本文档用于执行 P1-013：验证 Ambari 3.0.0 在 Ubuntu 22.04 + JDK 8 环境下是否能对接 Bigtop apt 仓库，并管理 Phase 1 P0 组件候选版本。

## 2. 输入基线

| 项目 | 值 |
|---|---|
| OS | Ubuntu 22.04 |
| JDK | JDK 8 |
| Ambari | 3.0.0 |
| Ambari 回退 | 2.7.9 |
| Ambari Metrics | 3.0.0 |
| Bigtop Repo | 3.5.0 apt 仓库 |
| 验证拓扑 | 3 Master + 3 Worker + 1 Gateway |

## 3. Ambari Server 检查

| 编号 | 检查项 | 结果 | 备注 |
|---|---|---|---|
| AMB-S-001 | Ambari Server 安装成功 | TODO |  |
| AMB-S-002 | Ambari Server 启动成功 | TODO |  |
| AMB-S-003 | Web UI 可访问 | TODO |  |
| AMB-S-004 | REST API 可访问 | TODO |  |
| AMB-S-005 | 使用 JDK 8 运行正常 | TODO |  |
| AMB-S-006 | 数据库初始化正常 | TODO |  |
| AMB-S-007 | 日志无阻塞级错误 | TODO |  |

## 4. Ambari Agent 检查

| 编号 | 检查项 | 结果 | 备注 |
|---|---|---|---|
| AMB-A-001 | 7 个节点 Agent 安装成功 | TODO |  |
| AMB-A-002 | 7 个节点 Agent 启动成功 | TODO |  |
| AMB-A-003 | Agent 心跳正常 | TODO |  |
| AMB-A-004 | Host 注册成功 | TODO |  |
| AMB-A-005 | Host 状态可见 | TODO |  |
| AMB-A-006 | Agent 日志无阻塞级错误 | TODO |  |

## 5. Ambari Metrics 检查

| 编号 | 检查项 | 结果 | 备注 |
|---|---|---|---|
| AMB-M-001 | Ambari Metrics 安装成功 | TODO |  |
| AMB-M-002 | Metrics Collector 启动成功 | TODO |  |
| AMB-M-003 | Metrics Monitor 正常 | TODO |  |
| AMB-M-004 | 主机基础指标可见 | TODO |  |
| AMB-M-005 | 服务指标可见 | TODO |  |

## 6. Repository 对接检查

| 编号 | 检查项 | 结果 | 备注 |
|---|---|---|---|
| REPO-001 | Bigtop apt 仓库可访问 | TODO |  |
| REPO-002 | Ambari Repository 配置可保存 | TODO |  |
| REPO-003 | repo id / baseurl 正确 | TODO |  |
| REPO-004 | apt update 可执行 | TODO |  |
| REPO-005 | Ambari 可触发包安装 | TODO |  |
| REPO-006 | 包名与服务定义匹配 | TODO |  |
| REPO-007 | 回退仓库策略明确 | TODO |  |

## 7. Blueprint 检查

| 编号 | 检查项 | 结果 | 备注 |
|---|---|---|---|
| BP-001 | 3M3W1G Blueprint 可创建 | TODO |  |
| BP-002 | Host Mapping 可创建 | TODO |  |
| BP-003 | HDFS HA 角色分布正确 | TODO |  |
| BP-004 | YARN HA 角色分布正确 | TODO |  |
| BP-005 | Hive 多实例角色分布正确 | TODO |  |
| BP-006 | Spark 角色分布正确 | TODO |  |
| BP-007 | HBase 角色分布正确 | TODO |  |
| BP-008 | ZooKeeper 角色分布正确 | TODO |  |

## 8. 服务安装检查

| 编号 | 组件 | 安装结果 | 配置结果 | 启动结果 | 备注 |
|---|---|---|---|---|---|
| SVC-001 | ZooKeeper | TODO | TODO | TODO |  |
| SVC-002 | HDFS | TODO | TODO | TODO |  |
| SVC-003 | YARN | TODO | TODO | TODO |  |
| SVC-004 | Hive | TODO | TODO | TODO |  |
| SVC-005 | Tez | TODO | TODO | TODO |  |
| SVC-006 | Spark | TODO | TODO | TODO |  |
| SVC-007 | HBase | TODO | TODO | TODO |  |

## 9. Service Check 检查

| 编号 | 组件 | Service Check 结果 | 失败原因 | 处理建议 |
|---|---|---|---|---|
| CHECK-001 | ZooKeeper | TODO |  |  |
| CHECK-002 | HDFS | TODO |  |  |
| CHECK-003 | YARN | TODO |  |  |
| CHECK-004 | Hive | TODO |  |  |
| CHECK-005 | Spark | TODO |  |  |
| CHECK-006 | HBase | TODO |  |  |

## 10. 管理操作检查

| 编号 | 检查项 | 结果 | 备注 |
|---|---|---|---|
| OPS-001 | 服务 Start | TODO |  |
| OPS-002 | 服务 Stop | TODO |  |
| OPS-003 | 服务 Restart | TODO |  |
| OPS-004 | 配置修改与下发 | TODO |  |
| OPS-005 | Restart Required 状态识别 | TODO |  |
| OPS-006 | 告警状态可见 | TODO |  |
| OPS-007 | Maintenance Mode 可用 | TODO |  |

## 11. 回退策略检查

| 编号 | 检查项 | 结果 | 备注 |
|---|---|---|---|
| RB-001 | Ambari 2.7.9 回退路径明确 | TODO |  |
| RB-002 | Bigtop 3.4.0 回退路径明确 | TODO |  |
| RB-003 | Repository 切换策略明确 | TODO |  |
| RB-004 | Blueprint 差异项记录 | TODO |  |

## 12. 缺陷记录模板

| 缺陷编号 | 模块 | 严重级别 | 描述 | 处理建议 | 状态 |
|---|---|---|---|---|---|
| BUG-001 | TBD | TBD | TBD | TBD | OPEN |

## 13. 输出结论

| 结论项 | 结果 |
|---|---|
| Ambari 3.0.0 是否可作为 Phase 1 管理面基线 | TODO |
| 是否需要回退 Ambari 2.7.9 | TODO |
| 是否可以进入 3M3W1G 集群验证 | TODO |
| 是否存在阻塞级适配问题 | TODO |

## 14. 关联文档

- `docs/ambari-version-strategy.md`
- `docs/phase1-version-validation-plan.md`
- `docs/phase1-ha-design.md`
- `docs/phase1-test-plan.md`
