# P1-012 Bigtop 3.5.0 构建验证检查表

## 1. 检查表目标

本文档用于执行 P1-012：验证 Bigtop 3.5.0 是否能够在 Ubuntu 22.04 + JDK 8 基线下构建 Phase 1 P0 组件候选版本，并输出 DEB 包与 apt 仓库。

## 2. 输入基线

| 项目 | 值 |
|---|---|
| OS | Ubuntu 22.04 |
| JDK | JDK 8 |
| Bigtop | 3.5.0 |
| 回退 Bigtop | 3.4.0 |
| 包格式 | DEB |
| 仓库类型 | apt |

## 3. 候选组件

| 组件 | 主候选 | 回退/评估 |
|---|---:|---:|
| Hadoop | 3.5.0 | 3.4.3 / 3.3.6 |
| ZooKeeper | 3.9.5 | 3.8.6 |
| Hive | 4.2.0 | 4.1.x / 3.x |
| Hive Standalone Metastore | 4.2.0 | 3.0.0 |
| Tez | 0.10.5 | 0.10.4 / 0.10.3 |
| Spark | 3.5.8 | 3.4.x |
| HBase | 2.5.14 | 2.5.13 |

## 4. 构建环境检查

| 编号 | 检查项 | 结果 | 备注 |
|---|---|---|---|
| ENV-001 | Ubuntu 22.04 版本确认 | TODO |  |
| ENV-002 | JDK 8 安装确认 | TODO |  |
| ENV-003 | JAVA_HOME 配置确认 | TODO |  |
| ENV-004 | 构建依赖安装确认 | TODO |  |
| ENV-005 | Bigtop 3.5.0 源码获取确认 | TODO |  |
| ENV-006 | 构建缓存目录确认 | TODO |  |
| ENV-007 | 输出目录确认 | TODO |  |

## 5. Bigtop 配置检查

| 编号 | 检查项 | 结果 | 备注 |
|---|---|---|---|
| CFG-001 | 是否支持 Ubuntu 22.04 目标 | TODO |  |
| CFG-002 | 是否支持 DEB 输出 | TODO |  |
| CFG-003 | 是否支持目标组件版本覆盖 | TODO |  |
| CFG-004 | 是否存在组件版本 BOM | TODO |  |
| CFG-005 | 是否需要 patch / overlay | TODO |  |
| CFG-006 | 是否支持 JDK 8 构建 | TODO |  |

## 6. 组件构建检查

| 编号 | 组件 | 候选版本 | 构建结果 | 失败原因 | 回退建议 |
|---|---|---:|---|---|---|
| BUILD-001 | Hadoop | 3.5.0 | TODO |  | 3.4.3 / 3.3.6 |
| BUILD-002 | ZooKeeper | 3.9.5 | TODO |  | 3.8.6 |
| BUILD-003 | Hive | 4.2.0 | TODO |  | 4.1.x / 3.x |
| BUILD-004 | Hive Standalone Metastore | 4.2.0 | TODO |  | 3.0.0 |
| BUILD-005 | Tez | 0.10.5 | TODO |  | 0.10.4 / 0.10.3 |
| BUILD-006 | Spark | 3.5.8 | TODO |  | 3.4.x |
| BUILD-007 | HBase | 2.5.14 | TODO |  | 2.5.13 |

## 7. DEB 包检查

| 编号 | 检查项 | 结果 | 备注 |
|---|---|---|---|
| DEB-001 | DEB 包是否生成 | TODO |  |
| DEB-002 | 包名是否符合 Ambari 预期 | TODO |  |
| DEB-003 | 包版本是否正确 | TODO |  |
| DEB-004 | 包依赖是否完整 | TODO |  |
| DEB-005 | 安装路径是否符合预期 | TODO |  |
| DEB-006 | systemd / service 脚本是否存在 | TODO |  |
| DEB-007 | 用户和目录权限是否合理 | TODO |  |

## 8. apt 仓库检查

| 编号 | 检查项 | 结果 | 备注 |
|---|---|---|---|
| APT-001 | 仓库目录结构正确 | TODO |  |
| APT-002 | metadata 生成成功 | TODO |  |
| APT-003 | Ubuntu 节点 apt update 成功 | TODO |  |
| APT-004 | 候选包可查询 | TODO |  |
| APT-005 | 候选包可安装 | TODO |  |
| APT-006 | 回退版本可保留 | TODO |  |
| APT-007 | 仓库快照策略明确 | TODO |  |

## 9. 缺陷记录模板

| 缺陷编号 | 组件 | 阶段 | 严重级别 | 描述 | 处理建议 | 状态 |
|---|---|---|---|---|---|---|
| BUG-001 | TBD | TBD | TBD | TBD | TBD | OPEN |

## 10. 输出结论

| 结论项 | 结果 |
|---|---|
| Bigtop 3.5.0 是否可作为 Phase 1 构建基线 | TODO |
| 是否需要回退 Bigtop 3.4.0 | TODO |
| 是否存在阻塞级组件 | TODO |
| 是否可以进入 Ambari 适配验证 | TODO |

## 11. 关联文档

- `docs/version-matrix.md`
- `docs/bigtop-build-design.md`
- `docs/phase1-version-validation-plan.md`
- `docs/phase1-test-plan.md`
