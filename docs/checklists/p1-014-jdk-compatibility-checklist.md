# P1-014 JDK 8 默认运行与 JDK 17 兼容性检查表

## 1. 检查表目标

本文档用于执行 P1-014：验证 Phase 1 候选版本在 JDK 8 下的默认构建与运行能力，并评估 JDK 17 的未来兼容路径。

## 2. 输入基线

| 项目 | 值 |
|---|---|
| OS | Ubuntu 22.04 |
| 默认 JDK | JDK 8 |
| 兼容性评估 | JDK 17 |
| 验证形态 | 构建验证 + 单组件运行验证 + 集群验证 |

## 3. 组件检查范围

| 组件 | Phase 1 候选 | JDK 8 | JDK 17 评估 | 备注 |
|---|---:|---|---|---|
| Ambari | 3.0.0 | TODO | TODO | Server / Agent |
| Hadoop | 3.5.0 | TODO | TODO | HDFS / YARN |
| ZooKeeper | 3.9.5 | TODO | TODO | 协调服务 |
| Hive | 4.2.0 | TODO | TODO | Metastore / HS2 |
| Hive Standalone Metastore | 4.2.0 | TODO | TODO | Spark SQL 依赖 |
| Tez | 0.10.5 | TODO | TODO | Hive 执行引擎 |
| Spark | 3.5.8 | TODO | TODO | Spark 4.1.x 另行升级评估 |
| HBase | 2.5.14 | TODO | TODO | HBase 2.6.5 另行升级评估 |

## 4. JDK 8 构建检查

| 编号 | 组件 | 构建结果 | 失败原因 | 处理建议 |
|---|---|---|---|---|
| J8-BUILD-001 | Hadoop 3.5.0 | TODO |  |  |
| J8-BUILD-002 | ZooKeeper 3.9.5 | TODO |  |  |
| J8-BUILD-003 | Hive 4.2.0 | TODO |  |  |
| J8-BUILD-004 | Metastore 4.2.0 | TODO |  |  |
| J8-BUILD-005 | Tez 0.10.5 | TODO |  |  |
| J8-BUILD-006 | Spark 3.5.8 | TODO |  |  |
| J8-BUILD-007 | HBase 2.5.14 | TODO |  |  |

## 5. JDK 8 运行检查

| 编号 | 组件 | 启动结果 | 基础功能 | 日志异常 | 备注 |
|---|---|---|---|---|---|
| J8-RUN-001 | Ambari Server / Agent | TODO | TODO | TODO |  |
| J8-RUN-002 | ZooKeeper | TODO | TODO | TODO |  |
| J8-RUN-003 | HDFS | TODO | TODO | TODO |  |
| J8-RUN-004 | YARN | TODO | TODO | TODO |  |
| J8-RUN-005 | Hive Metastore | TODO | TODO | TODO |  |
| J8-RUN-006 | HiveServer2 | TODO | TODO | TODO |  |
| J8-RUN-007 | Spark | TODO | TODO | TODO |  |
| J8-RUN-008 | HBase | TODO | TODO | TODO |  |

## 6. JDK 17 兼容性评估

| 编号 | 组件 | 构建评估 | 启动评估 | 风险 | 升级建议 |
|---|---|---|---|---|---|
| J17-001 | Ambari 3.0.0 | TODO | TODO |  |  |
| J17-002 | Hadoop 3.5.0 | TODO | TODO |  |  |
| J17-003 | ZooKeeper 3.9.5 | TODO | TODO |  |  |
| J17-004 | Hive 4.2.0 | TODO | TODO |  |  |
| J17-005 | Spark 3.5.8 | TODO | TODO |  |  |
| J17-006 | Spark 4.1.x | TODO | TODO |  | 未来升级评估 |
| J17-007 | HBase 2.5.14 | TODO | TODO |  |  |
| J17-008 | HBase 2.6.5 | TODO | TODO |  | 未来升级评估 |

## 7. 重点风险检查

| 风险项 | 检查结果 | 备注 |
|---|---|---|
| Java 模块化导致反射访问失败 | TODO |  |
| 第三方依赖版本冲突 | TODO |  |
| Hadoop / Hive / Spark classpath 冲突 | TODO |  |
| Ambari 脚本硬编码 JAVA_HOME | TODO |  |
| JDK 17 下非法访问警告升级为错误 | TODO |  |
| Spark / Hive Metastore 客户端兼容问题 | TODO |  |
| HBase 与 Hadoop / ZooKeeper 客户端兼容问题 | TODO |  |

## 8. 输出结论

| 结论项 | 结果 |
|---|---|
| JDK 8 是否可作为 Phase 1 默认运行时 | TODO |
| 是否存在 JDK 8 阻塞级问题 | TODO |
| JDK 17 是否具备未来升级路径 | TODO |
| 是否需要调整候选版本 | TODO |

## 9. 关联文档

- `docs/version-matrix.md`
- `docs/phase1-version-validation-plan.md`
- `docs/phase1-test-plan.md`
