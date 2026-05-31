# P3-001-A Ambari 3.0.0 Viability Review

## 1. 文档目标

本文档用于评审 Ambari 3.0.0 是否适合作为 BIGDATA-1.0 的长期 Management Backend。

本评审区别于“Ambari 3.0.0 是否存在发布包”。存在源码发布只说明可以进入验证，不代表适合作为 BIGDATA-1.0 的长期管理面。

## 2. 当前公开事实

| 事实 | 说明 | 初步结论 |
|---|---|---|
| Apache 下载目录存在 `ambari-3.0.0` | 说明 Ambari 3.0.0 有 ASF 源码发布 | 可进入源码验证 |
| Apache 下载目录存在 `ambari-metrics-3.0.0` | 说明 Metrics 有对应版本发布 | 可进入源码验证 |
| 下载目录同时存在 2.7.9 | 说明 2.7.9 可作为兼容回退候选 | 作为回退线保留 |

## 3. Viability Review 核心问题

必须回答：

```text
Ambari 3.0.0 是否值得作为 BIGDATA-1.0 的长期管理后端投入适配？
```

而不是仅回答：

```text
Ambari 3.0.0 是否存在？
```

## 4. 评审维度

| 维度 | 目标 | 风险 |
|---|---|---|
| 项目活跃度 | 判断是否有持续维护能力 | 高 |
| 构建可行性 | 判断能否在 Ubuntu 22.04 / JDK 8 构建 | 高 |
| 运行兼容性 | 判断 Server/Agent 是否可运行 | 高 |
| Repository 适配 | 判断能否对接 Bigtop apt 仓库 | 高 |
| Stack Definition 适配 | 判断能否管理 Hadoop/Hive/Spark/HBase 候选版本 | 极高 |
| Blueprint 能力 | 判断能否支撑 3M3W1G 自动部署 | 高 |
| Metrics / Alerts | 判断运维体验是否完整 | 中 |
| 回退与替代 | 判断失败后的替代路径 | 极高 |

## 5. Agent-A1 项目活跃度验证

### 5.1 验证目标

判断 Ambari 3.0.0 是否仍具备社区维护和长期演进基础。

### 5.2 验证项

| 编号 | 验证项 | 结果 | 证据 | 结论 |
|---|---|---|---|---|
| A1-001 | ASF 下载目录是否存在 3.0.0 | 初步 PASS | Apache downloads | 待签名校验 |
| A1-002 | 3.0.0 发布时间 | TODO |  |  |
| A1-003 | 最近提交时间 | TODO |  |  |
| A1-004 | 最近 Release 频率 | TODO |  |  |
| A1-005 | 活跃维护者数量 | TODO |  |  |
| A1-006 | 是否存在已知严重 Issue | TODO |  |  |

### 5.3 输出结论

```yaml
projectActivity:
  status: TODO
  risk: TODO
  recommendation: TODO
```

## 6. Agent-A2 技术兼容矩阵验证

### 6.1 验证目标

判断 Ambari 3.0.0 是否能在 BIGDATA-1.0 默认环境运行。

BIGDATA-1.0 默认环境：

```text
Ubuntu 22.04 + JDK 8 + bare-metal/vm
```

### 6.2 验证项

| 编号 | 验证项 | 结果 | 证据 | 结论 |
|---|---|---|---|---|
| A2-001 | Ubuntu 22.04 构建 | TODO |  |  |
| A2-002 | Ubuntu 22.04 安装 Ambari Server | TODO |  |  |
| A2-003 | Ubuntu 22.04 安装 Ambari Agent | TODO |  |  |
| A2-004 | JDK 8 构建兼容 | TODO |  |  |
| A2-005 | JDK 8 运行兼容 | TODO |  |  |
| A2-006 | JDK 17 构建评估 | TODO |  |  |
| A2-007 | JDK 17 运行评估 | TODO |  |  |

### 6.3 输出结论

```yaml
technicalCompatibility:
  ubuntu22: TODO
  jdk8: TODO
  jdk17Evaluation: TODO
  blocker: TODO
```

## 7. Agent-A3 服务管理能力验证

### 7.1 验证目标

判断 Ambari 3.0.0 是否能管理 BIGDATA-1.0 候选组件。

候选组件：

- Hadoop 3.5.0
- ZooKeeper 3.9.5
- Hive 4.2.0
- Hive Standalone Metastore 4.2.0
- Tez 0.10.5
- Spark 3.5.8
- HBase 2.5.14

### 7.2 验证项

| 编号 | 验证项 | 结果 | 风险 |
|---|---|---|---|
| A3-001 | Ambari Stack Definition 是否支持 Hadoop 3.5.0 | TODO | 极高 |
| A3-002 | 是否支持 HDFS HA / YARN HA | TODO | 高 |
| A3-003 | 是否支持 Hive 4.2.0 | TODO | 极高 |
| A3-004 | 是否支持 Hive Metastore 4.2.0 | TODO | 高 |
| A3-005 | 是否支持 Spark 3.5.8 | TODO | 高 |
| A3-006 | 是否支持 HBase 2.5.14 | TODO | 高 |
| A3-007 | 是否支持 Tez 0.10.5 | TODO | 中 |
| A3-008 | Service Advisor 是否需要重写 | TODO | 高 |
| A3-009 | Alert Definition 是否需要适配 | TODO | 中 |
| A3-010 | Metrics Definition 是否需要适配 | TODO | 中 |
| A3-011 | Service Check 是否需要适配 | TODO | 高 |
| A3-012 | Blueprint 是否能安装 3M3W1G | TODO | 高 |

### 7.3 关键判断

如果 Ambari 3.0.0 不能原生支持候选组件，需要判断适配成本：

```text
低：少量 Stack Definition 修改
中：需要 Service Definition + Alert + Metrics 修改
高：需要重写多组件 Stack、Service Advisor、Service Check
不可接受：核心服务无法稳定管理
```

## 8. Agent-A4 替代方案评估

### 8.1 方案列表

| 方案 | 说明 |
|---|---|
| Ambari 3.0.0 | Phase 1 主候选 |
| Ambari 2.7.9 | 兼容回退候选 |
| Custom Backend | Platform Core + Agent + systemd，自研管理后端 |
| Hybrid | Ambari 管理基础服务，自研补充验证/运维能力 |

### 8.2 评估维度

| 维度 | Ambari 3.0.0 | Ambari 2.7.9 | Custom Backend | Hybrid |
|---|---|---|---|---|
| 组件兼容 | TODO | TODO | TODO | TODO |
| Ubuntu 22.04 | TODO | TODO | TODO | TODO |
| JDK 8 | TODO | TODO | TODO | TODO |
| Hadoop 3.5 | TODO | TODO | TODO | TODO |
| Hive 4.2 | TODO | TODO | TODO | TODO |
| 工程成本 | TODO | TODO | TODO | TODO |
| 长期可控性 | TODO | TODO | TODO | TODO |
| 上手成本 | TODO | TODO | TODO | TODO |
| 交付风险 | TODO | TODO | TODO | TODO |

## 9. 决策门槛

### 9.1 继续 Ambari 3.0.0 路线

需要满足：

- Ambari Server 可安装运行
- Ambari Agent 可注册
- Repository 可对接
- 至少 Hadoop / ZooKeeper / HDFS / YARN 可管理
- Hive / Spark / HBase 适配成本可接受
- 3M3W1G Blueprint 有可行路径

### 9.2 切换回退路线

如果出现以下情况，应考虑回退或替代：

- Ambari 3.0.0 在 Ubuntu 22.04 / JDK 8 下无法稳定运行
- 核心 Stack Definition 缺失严重
- 管理 Hadoop 3.5.0 成本过高
- Hive / Spark / HBase 需要大量重写且不可控
- 社区维护不足以支撑长期路线

## 10. 初步风险判断

当前只能确认 Ambari 3.0.0 有 ASF 源码发布。是否适合作为 BIGDATA-1.0 管理后端仍为 UNKNOWN。

风险等级：

```text
极高
```

建议优先执行真实验证，不允许仅基于发布存在性冻结管理后端。

## 11. 输出结论模板

```yaml
ambariViabilityReview:
  candidate: ambari-3.0.0
  decision: TODO # ACCEPT / CONDITIONAL_ACCEPT / REJECT / FALLBACK
  evidence:
    - TODO
  blockers:
    - TODO
  adaptationCost: TODO # low / medium / high / unacceptable
  fallback:
    - ambari-2.7.9
    - custom-backend
    - hybrid
```

## 12. 后续动作

- 创建 P3-001-A1 项目活跃度验证 Issue
- 创建 P3-001-A2 技术兼容矩阵验证 Issue
- 创建 P3-001-A3 服务管理能力验证 Issue
- 创建 P3-001-A4 替代方案评估 Issue
