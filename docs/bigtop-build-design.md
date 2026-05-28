# Bigtop 构建体系设计

## 1. 文档目标

本文档定义 Bigdata Platform 第一阶段基于 Apache Bigtop 的真实组件构建、包管理、仓库发布和 Ambari 对接方案。

## 2. 已确认基线

| 项目 | 确认结果 |
|---|---|
| Bigtop 定位 | 真实构建体系 |
| 目标 OS | Ubuntu 22.04 |
| JDK | JDK 8，预留 JDK 17 兼容评估 |
| 交付形态 | Bigtop 包仓库 + Ambari Blueprint + Runbook + Smoke Test |
| 第一阶段组件 | Hadoop、Hive、Spark、HBase、ZooKeeper 相关依赖 |

## 3. 构建目标

Bigtop 在第一阶段需要承担：

- 组件版本矩阵维护
- 组件包构建
- DEB 包输出
- apt 仓库发布
- 包仓库元数据生成
- Ambari Repository 对接
- Smoke Test 与基础验证

## 4. 构建流程

```text
选择版本矩阵
  -> 准备 Ubuntu 22.04 构建环境
  -> 准备 JDK 8
  -> 拉取 Bigtop 源码
  -> 构建 Hadoop / Hive / Spark / HBase 等组件包
  -> 生成 DEB 包
  -> 发布 apt 仓库
  -> 配置 Ambari Repository
  -> 使用 Ambari 安装集群
  -> 执行 Service Check / Smoke Test
```

## 5. 第一阶段构建组件

| 组件 | 说明 | 优先级 |
|---|---|---|
| Hadoop | HDFS / YARN / MapReduce 基础组件 | P0 |
| ZooKeeper | HDFS HA、YARN HA、HBase 依赖 | P0 |
| Hive | Metastore、HiveServer2、SQL 能力 | P0 |
| Spark | 批处理和离线 SQL 补充 | P0 |
| HBase | 宽表存储，第一阶段真实验证 | P0 |
| Tez | Hive 执行引擎，按 Hive 方案确定 | P1 |

## 6. 构建环境设计

### 6.1 OS

第一阶段标准构建环境为：

```text
Ubuntu 22.04
```

### 6.2 JDK

第一阶段默认：

```text
JDK 8
```

兼容性评估：

```text
JDK 17
```

JDK 17 不作为第一阶段默认运行时，但需要在版本矩阵中保留兼容性评估项。

### 6.3 构建节点要求

建议构建节点具备：

- 足够 CPU 与内存
- 稳定网络
- 独立构建缓存目录
- 独立包输出目录
- 可访问内部 Git 与制品仓库

## 7. 包仓库设计

第一阶段使用 apt 仓库，对 Ubuntu 22.04 提供 DEB 包。

```text
repo-root/
├── dists/
│   └── jammy/
├── pool/
│   └── main/
└── conf/
```

仓库需要支持：

- 内网访问
- 版本隔离
- 快照保留
- 回滚
- 与 Ambari Repository 配置对接

## 8. Ambari 对接

Ambari 通过 Repository 配置消费 Bigtop 发布的包仓库。

对接内容包括：

- repo id
- base url
- OS family
- stack version
- package name
- component name

第一阶段优先使用最新可维护的社区/发行版最新兼容 Ambari 版本。

## 9. 版本矩阵

需要单独维护版本矩阵，至少包括：

| 组件 | 版本 | JDK 8 | JDK 17 评估 | Ubuntu 22.04 | 备注 |
|---|---|---|---|---|---|
| Hadoop | TBD | 必选 | 评估 | 必选 | HDFS/YARN |
| Hive | TBD | 必选 | 评估 | 必选 | Metastore/HS2 |
| Spark | TBD | 必选 | 评估 | 必选 | 批处理 |
| HBase | TBD | 必选 | 评估 | 必选 | 宽表 |
| ZooKeeper | TBD | 必选 | 评估 | 必选 | 协调 |

## 10. 构建验证

### 10.1 包级验证

- 包能成功构建
- 包依赖完整
- 包可安装
- 包版本可查询
- 包卸载无残留风险

### 10.2 仓库级验证

- apt update 成功
- apt install 成功
- 仓库元数据正确
- 版本 pinning 可控

### 10.3 集群级验证

- Ambari 能识别仓库
- Ambari 能安装组件
- 服务能启动
- Service Check 通过
- Smoke Test 通过

## 11. Agent 分工

| Agent | 职责 |
|---|---|
| Build Agent | Bigtop 构建流程、构建环境 |
| Version Agent | 组件版本矩阵、兼容性 |
| Repo Agent | apt 仓库发布与回滚 |
| Ambari Agent | Ambari Repository 对接 |
| QA Agent | 包级、仓库级、集群级验证 |

## 12. 后续待办

- [ ] 明确 Bigtop 版本或分支
- [ ] 明确 Hadoop/Hive/Spark/HBase 版本
- [ ] 补充 Ubuntu 22.04 apt 仓库发布脚本
- [ ] 补充 JDK 17 兼容性评估表
- [ ] 补充 Ambari Repository 配置样例
- [ ] 补充构建失败排查 Runbook
