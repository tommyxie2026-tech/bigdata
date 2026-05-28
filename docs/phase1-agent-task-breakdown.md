# Phase 1 Agent 任务拆分

## 1. 文档目标

本文档定义 Bigdata Platform 第一阶段的 Agent 并行执行任务拆分，用于后续按 Issue、PR 或任务流推进设计、工程和验证工作。

## 2. Phase 1 基线

| 项目 | 结果 |
|---|---|
| 阶段目标 | 传统数仓物理机 HA 底座 |
| OS | Ubuntu 22.04 |
| JDK | JDK 8，预留 JDK 17 兼容评估 |
| 规模 | 3 Master + 3 Worker + 1 Gateway |
| 管理面 | Ambari |
| 构建体系 | Bigtop |
| 交付形态 | Bigtop 包仓库 + Ambari Blueprint + Runbook + Smoke Test |
| 安全 | Kerberos 设计保留，不默认启用 |

## 3. Agent 总览

| Agent | 主要职责 |
|---|---|
| Architecture Agent | 架构收敛、决策记录、跨文档一致性 |
| Version Agent | 版本矩阵、JDK 兼容性、候选版本冻结 |
| Bigtop Agent | 真实构建、DEB 包、apt 仓库 |
| Ambari Agent | Ambari 版本、安装、Repository、Blueprint |
| Deployment Agent | 3M3W1G 拓扑、网络、磁盘、端口 |
| Hadoop Agent | ZooKeeper、HDFS HA、YARN HA |
| Warehouse Agent | Hive、Spark、数仓能力 |
| HBase Agent | HBase 部署、HA、Smoke Test、Runbook |
| Security Agent | 账号、权限、Kerberos 预留、安全基线 |
| Operations Agent | Runbook、巡检、恢复、扩容、升级 |
| QA Agent | 测试计划、Smoke Test、验收报告 |
| Review Agent | 文档评审、冲突检查、合并建议 |

## 4. 任务拆分

### 4.1 Architecture Agent

输入：

- `platform-overview.md`
- `architecture-decisions.md`
- `roadmap.md`

输出：

- 文档一致性检查
- 架构术语统一
- ADR 维护
- 第一阶段边界控制

验收：

- 所有 P0 文档与 ADR 一致
- 不出现第一阶段范围漂移

### 4.2 Version Agent

任务：

- 收集 Ambari 候选版本
- 收集 Bigtop 候选版本或分支
- 收集 Hadoop / Hive / Spark / HBase / ZooKeeper 候选版本
- 维护 JDK 8 / JDK 17 兼容性矩阵
- 输出版本冻结建议

输出：

- `docs/version-matrix.md` 修订版
- 版本冻结记录

### 4.3 Bigtop Agent

任务：

- 设计 Ubuntu 22.04 构建环境
- 设计 JDK 8 构建流程
- 设计 DEB 包输出流程
- 设计 apt 仓库发布流程
- 验证 Hadoop / Hive / Spark / HBase 包构建路径

输出：

- `docs/bigtop-build-design.md` 修订版
- `bigtop/build/` 工程任务建议
- `bigtop/repo/` 工程任务建议

### 4.4 Ambari Agent

任务：

- 评估 Ambari 最新可维护兼容版本
- 设计 Ubuntu 22.04 Ambari 安装流程
- 设计 Ambari Repository 对接 Bigtop apt 仓库
- 设计 3M3W1G Blueprint
- 设计 Service Check 验证流程

输出：

- `docs/ambari-version-strategy.md` 修订版
- `ambari/blueprints/` 任务建议
- `ambari/runbooks/` 任务建议

### 4.5 Deployment Agent

任务：

- 细化 3 Master + 3 Worker + 1 Gateway 拓扑
- 补充主机规格建议
- 补充磁盘规划
- 补充网络规划
- 补充端口矩阵

输出：

- `docs/phase1-ha-design.md` 修订版
- `docs/deployment-design.md` 修订版

### 4.6 Hadoop Agent

任务：

- 细化 ZooKeeper 设计
- 细化 HDFS HA 设计
- 细化 YARN HA 设计
- 补充 Failover 验证步骤
- 补充 HDFS/YARN Runbook 需求

输出：

- HDFS/YARN/ZooKeeper 专项设计草案
- HA 验证步骤

### 4.7 Warehouse Agent

任务：

- 细化 Hive Metastore 多实例设计
- 细化 HiveServer2 多实例设计
- 细化 Spark History Server 与 Spark Client 设计
- 定义 Hive/Spark Smoke Test

输出：

- Hive/Spark 专项设计草案
- 数仓验证用例

### 4.8 HBase Agent

任务：

- 细化 HBase Master / RegionServer 部署
- 定义 HBase 配置模板
- 定义 HBase Smoke Test
- 定义 HBase 故障恢复 Runbook
- 评估 HBase 与 JDK 17 兼容性

输出：

- `docs/hbase-design.md` 修订版
- HBase 配置模板任务建议
- HBase Runbook 任务建议

### 4.9 Security Agent

任务：

- 定义账号权限矩阵
- 定义服务账号目录权限
- 定义 Ambari 账号安全规范
- 定义 Kerberos 后续启用路径
- 定义包仓库访问策略

输出：

- `docs/security-design.md` 修订版
- 安全检查清单

### 4.10 Operations Agent

任务：

- 补充安装 Runbook
- 补充重启 Runbook
- 补充 HBase 恢复 Runbook
- 补充巡检 Runbook
- 补充扩容与升级设计保留项

输出：

- `ambari/runbooks/` 修订建议
- `docs/operations-design.md` 修订版

### 4.11 QA Agent

任务：

- 维护 Phase 1 测试计划
- 定义 Smoke Test 用例
- 定义缺陷记录模板
- 定义验收报告模板
- 汇总测试结果

输出：

- `docs/phase1-test-plan.md` 修订版
- `docs/phase1-acceptance-criteria.md` 修订版

### 4.12 Review Agent

任务：

- 检查所有 P0 文档是否遵循 ADR
- 检查术语一致性
- 检查第一阶段范围是否漂移
- 检查交付物是否可验收
- 输出 Review 结论

输出：

- Review 报告
- 修订建议
- 合并建议

## 5. 建议 Issue 拆分

| Issue | Agent | 标题 |
|---|---|---|
| P1-001 | Version Agent | 确认 Phase 1 版本矩阵 |
| P1-002 | Bigtop Agent | 设计 Ubuntu 22.04 Bigtop 构建与 apt 仓库 |
| P1-003 | Ambari Agent | 确认 Ambari 版本与 Blueprint 设计 |
| P1-004 | Deployment Agent | 细化 3M3W1G HA 拓扑与端口矩阵 |
| P1-005 | Hadoop Agent | 细化 HDFS/YARN/ZooKeeper HA 设计 |
| P1-006 | Warehouse Agent | 细化 Hive/Spark 数仓设计 |
| P1-007 | HBase Agent | 细化 HBase 验证设计 |
| P1-008 | Security Agent | 完成 Phase 1 安全基线设计 |
| P1-009 | Operations Agent | 完成 Runbook 体系设计 |
| P1-010 | QA Agent | 完成 Smoke Test 与验收模板 |
| P1-011 | Review Agent | 执行 Phase 1 设计 Review |

## 6. PR 合并规则建议

- 每个 Agent 单独分支
- 每个 Agent 输出独立 PR
- Review Agent 做交叉审查
- Architecture Agent 负责最终冲突收敛
- 所有 P0 文档更新后再进入工程脚本阶段

## 7. 当前暂停事项

Phase 1 设计 Review 完成前，暂不推进：

- 完整自定义 Ambari Stack 实现
- 大规模脚本工程化
- Kubernetes Operator 实现
- 实时数据湖组件落地
- Kerberos 默认启用

## 8. 后续待办

- [ ] 创建 Phase 1 Issue 列表
- [ ] 为每个 Agent 定义输入输出模板
- [ ] 创建 Review Checklist
- [ ] 确认 PR 分支命名规范
