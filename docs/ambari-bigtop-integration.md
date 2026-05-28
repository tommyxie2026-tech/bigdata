# Ambari 与 Apache Bigtop 集成设计

## 1. 文档目标

本文档用于说明 `bigdata` 项目中 Apache Ambari 与 Apache Bigtop 的集成方式，目标是形成从组件真实构建、包管理、仓库发布、Ambari 安装、HA 集群部署到部署验证的闭环。

## 2. 背景

Ambari 负责传统 Hadoop 生态集群的安装、配置、服务管理、监控和告警，并作为物理机和虚拟机部署形态下的长期管理面。

Apache Bigtop 在本项目中不是单纯参考资料，而是进入真实构建体系，承担大数据组件的打包、版本构建、依赖管理、测试验证和发行物管理。

两者结合后，可以形成如下职责划分：

| 项目 | 职责 |
|---|---|
| Apache Bigtop | 构建大数据组件包、维护版本矩阵、生成 yum/apt 仓库、执行包级和组件级测试 |
| Apache Ambari | 使用仓库中的组件包完成集群安装、服务配置、HA 配置、服务启停与运维管理 |
| bigdata 仓库 | 沉淀集成文档、构建脚本、配置模板、Blueprint、runbook、验证脚本和交付流程 |

## 3. 第一阶段构建范围

第一阶段 Bigtop 真实构建体系应覆盖传统数仓物理机 HA 底座所需组件：

- Hadoop / HDFS / YARN
- ZooKeeper
- Hive / Hive Metastore / HiveServer2
- Spark
- HBase
- 相关依赖包

Kafka、Flink、Iceberg、Trino 等进入第三阶段实时数据湖扩展，不作为第一阶段构建主线。

## 4. 总体流程

```text
Source / Spec / Patch
    |
    v
Apache Bigtop Build
    |
    v
RPM / DEB Packages
    |
    v
Package Repository
    |
    v
Ambari Repository Config
    |
    v
Ambari Blueprint / Install Wizard
    |
    v
Hadoop HA Cluster
    |
    v
Service Check / Smoke Test / Runbook
```

## 5. 集成架构

```text
┌────────────────────────────────────────────┐
│                bigdata 仓库                 │
│                                            │
│ docs / ambari / bigtop / scripts / runbooks │
└────────────────────────────────────────────┘
                    |
                    v
┌────────────────────────────────────────────┐
│              Apache Bigtop                 │
│                                            │
│ Build / Package / Repo / Test              │
└────────────────────────────────────────────┘
                    |
                    v
┌────────────────────────────────────────────┐
│              Package Repository             │
│                                            │
│ yum / apt / local mirror / offline repo     │
└────────────────────────────────────────────┘
                    |
                    v
┌────────────────────────────────────────────┐
│              Apache Ambari                  │
│                                            │
│ Repository / Stack / Service / Blueprint    │
└────────────────────────────────────────────┘
                    |
                    v
┌────────────────────────────────────────────┐
│              Hadoop Runtime Cluster         │
│                                            │
│ HDFS HA / YARN HA / Hive / Spark / HBase    │
└────────────────────────────────────────────┘
```

## 6. 目录规划

```text
bigdata/
├── ambari/
│   ├── blueprints/
│   ├── configs/
│   ├── scripts/
│   └── runbooks/
├── bigtop/
│   ├── README.md
│   ├── build/
│   ├── repo/
│   ├── tests/
│   └── version-matrix.md
└── docs/
    ├── technical-design.md
    ├── architecture-decisions.md
    ├── ambari-management-plane.md
    └── ambari-bigtop-integration.md
```

## 7. 关键集成点

### 7.1 版本矩阵

需要明确 Hadoop 生态组件版本之间的兼容关系，例如：

- Hadoop
- ZooKeeper
- Hive
- Spark
- HBase
- Tez
- Ambari
- JDK
- OS

版本矩阵由 Bigtop 构建侧维护，Ambari 安装侧消费。

### 7.2 软件包仓库

Bigtop 构建完成后，应生成内部 yum/apt 仓库，供 Ambari 安装组件时使用。

仓库配置需要包括：

- repo id
- baseurl
- gpgcheck
- enabled
- priority
- offline mirror 支持

### 7.3 Ambari Repository 配置

Ambari 需要知道组件包所在仓库地址。生产环境建议使用内部镜像仓库或离线仓库，不直接依赖外部公网仓库。

### 7.4 Blueprint 与配置模板

Ambari Blueprint 应与 Bigtop 版本矩阵保持一致，避免出现服务组件存在但软件包版本不匹配的问题。

### 7.5 HA 集成

第一阶段需要验证：

- HDFS NameNode HA
- YARN ResourceManager HA
- ZooKeeper 三节点
- Hive Metastore 多实例
- HiveServer2 多实例
- HBase Master HA
- HBase RegionServer 分布

### 7.6 集成测试

Bigtop 侧负责基础包和组件级测试，Ambari 侧负责服务安装、启动和服务检查。

建议测试链路：

```text
Package Build Test
  -> Repo Metadata Test
  -> Ambari Install Test
  -> HA Service Check
  -> Smoke Test
  -> Runbook Verification
```

## 8. 标准交付流程

### 8.1 构建阶段

1. 选择版本矩阵
2. 使用 Bigtop 构建组件包
3. 生成 RPM / DEB 包
4. 生成 yum / apt 仓库元数据
5. 发布到内部仓库或离线仓库

### 8.2 安装阶段

1. 配置 Ambari repository
2. 注册主机
3. 选择 Ambari Blueprint
4. 创建集群
5. 启动服务
6. 配置 HA
7. 执行服务检查

### 8.3 验证阶段

1. 检查 Ambari Dashboard
2. 执行 HDFS / YARN / Hive / HBase 服务检查
3. 执行 smoke test
4. 验证 HA 切换流程
5. 记录版本、配置和部署结果

## 9. 风险与约束

| 风险 | 说明 | 应对策略 |
|---|---|---|
| 版本不兼容 | Hadoop 生态组件依赖复杂 | 维护明确版本矩阵 |
| 构建成本高 | Bigtop 真实构建需要环境、依赖和时间 | 分阶段构建核心组件 |
| 仓库不可用 | Ambari 安装依赖包仓库 | 使用内部镜像和离线仓库 |
| 配置不一致 | Blueprint 与包版本不匹配 | 配置模板与版本矩阵绑定 |
| HA 验证复杂 | HA 涉及组件多、故障路径多 | 建立专项 HA 验收清单 |
| 运维复杂 | 多组件重启和依赖复杂 | 沉淀 runbook 与自动化脚本 |

## 10. 后续待办

- [ ] 明确目标 OS
- [ ] 明确目标 JDK
- [ ] 明确 Ambari 版本来源
- [ ] 完善 Bigtop 真实构建脚本
- [ ] 完善第一阶段组件版本矩阵
- [ ] 新增 HBase 构建与部署说明
- [ ] 新增 HA 验证清单
- [ ] 新增离线仓库发布说明
