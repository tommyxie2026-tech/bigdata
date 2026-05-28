# Ambari 与 Apache Bigtop 集成设计

## 1. 文档目标

本文档用于说明 `bigdata` 项目中 Apache Ambari 与 Apache Bigtop 的集成方式，目标是形成从组件构建、包管理、仓库发布、集群安装到部署验证的闭环。

## 2. 背景

Ambari 负责 Hadoop 生态集群的安装、配置、服务管理、监控和告警。

Apache Bigtop 更适合承担大数据组件的打包、版本构建、依赖管理、测试验证和发行物管理。

两者结合后，可以形成如下职责划分：

| 项目 | 职责 |
|---|---|
| Apache Bigtop | 构建大数据组件包、维护版本矩阵、生成 yum/apt 仓库、执行集成测试 |
| Apache Ambari | 使用仓库中的组件包完成集群安装、服务配置、服务启停与运维管理 |
| bigdata 仓库 | 沉淀集成文档、配置模板、脚本、Blueprint、runbook 和验证流程 |

## 3. 总体流程

```text
Source / Spec
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
Hadoop Cluster
    |
    v
Service Check / Smoke Test / Runbook
```

## 4. 集成架构

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
│ yum / apt / local mirror                    │
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
│ HDFS / YARN / Hive / Spark / HBase / Kafka  │
└────────────────────────────────────────────┘
```

## 5. 目录规划

建议在仓库中增加 `bigtop/` 目录，与 `ambari/` 并列：

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
    ├── ambari-management-plane.md
    └── ambari-bigtop-integration.md
```

## 6. 关键集成点

### 6.1 版本矩阵

需要明确 Hadoop 生态组件版本之间的兼容关系，例如：

- Hadoop
- Hive
- Spark
- HBase
- ZooKeeper
- Kafka
- Tez
- Ranger / Knox / Atlas

版本矩阵应由 Bigtop 构建侧维护，Ambari 安装侧消费。

### 6.2 软件包仓库

Bigtop 构建完成后，应生成内部 yum/apt 仓库，供 Ambari 安装组件时使用。

仓库配置需要包括：

- repo id
- baseurl
- gpgcheck
- enabled
- priority

### 6.3 Ambari Repository 配置

Ambari 需要知道组件包所在仓库地址。生产环境建议使用内部镜像仓库，不直接依赖外部公网仓库。

### 6.4 Blueprint 与配置模板

Ambari Blueprint 应与 Bigtop 版本矩阵保持一致，避免出现服务组件存在但软件包版本不匹配的问题。

### 6.5 集成测试

Bigtop 侧负责基础包和组件级测试，Ambari 侧负责服务安装、启动和服务检查。

建议测试链路：

```text
Package Build Test
  -> Repo Metadata Test
  -> Ambari Install Test
  -> Service Check
  -> Smoke Test
```

## 7. 标准交付流程

### 7.1 构建阶段

1. 选择版本矩阵
2. 使用 Bigtop 构建组件包
3. 生成 RPM / DEB 包
4. 生成 yum / apt 仓库元数据
5. 发布到内部仓库

### 7.2 安装阶段

1. 配置 Ambari repository
2. 注册主机
3. 选择 Ambari Blueprint
4. 创建集群
5. 启动服务
6. 执行服务检查

### 7.3 验证阶段

1. 检查 Ambari Dashboard
2. 执行 HDFS / YARN / Hive 服务检查
3. 执行 smoke test
4. 记录版本、配置和部署结果

## 8. 风险与约束

| 风险 | 说明 | 应对策略 |
|---|---|---|
| 版本不兼容 | Hadoop 生态组件依赖复杂 | 维护明确版本矩阵 |
| 仓库不可用 | Ambari 安装依赖包仓库 | 使用内部镜像和离线仓库 |
| 配置不一致 | Blueprint 与包版本不匹配 | 配置模板与版本矩阵绑定 |
| 测试不足 | 包能安装但服务不可用 | 增加服务检查与 smoke test |
| 运维复杂 | 多组件重启和依赖复杂 | 沉淀 runbook 与自动化脚本 |

## 9. 后续待办

- [ ] 新增 Bigtop 目录说明
- [ ] 新增大数据组件版本矩阵
- [ ] 新增本地包仓库说明
- [ ] 新增 Bigtop 构建脚本骨架
- [ ] 新增 Ambari 仓库配置模板
- [ ] 新增 smoke test 脚本
