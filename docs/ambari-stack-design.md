# 自定义 Ambari Stack 设计

## 1. 文档目标

本文档用于说明 `bigdata` 项目中自定义 Ambari Stack 的设计思路、目录结构、服务定义、仓库配置和演进路线。

第三阶段的目标是：在已有 Ambari 管理面和 Bigtop 构建体系之上，定义一个面向本项目的大数据发行版 Stack，使 Ambari 能够以标准 Stack / Service 的方式识别、安装和管理 Bigdata 平台组件。

## 2. 背景

前两个阶段已经完成：

1. Ambari 管理面设计与基础工程骨架
2. Ambari + Bigtop 构建、包管理、仓库发布和验证流程

下一步需要把组件、服务、配置、脚本和仓库描述组织成 Ambari Stack。

## 3. Stack 定位

自定义 Stack 可以命名为 `BIGDATA`，版本从 `1.0` 开始。

```text
BIGDATA-1.0
  ├── HDFS
  ├── YARN
  ├── MAPREDUCE2
  ├── HIVE
  ├── SPARK
  ├── ZOOKEEPER
  └── 后续扩展服务
```

在 Ambari 中，Stack 的职责包括：

- 描述平台支持的服务集合
- 描述每个服务的组件与角色
- 描述服务配置文件
- 描述服务控制脚本
- 描述软件包仓库
- 描述服务检查逻辑

## 4. 推荐目录结构

```text
ambari/stacks/
└── BIGDATA/
    └── 1.0/
        ├── metainfo.xml
        ├── repos/
        │   └── repoinfo.xml
        └── services/
            ├── HDFS/
            │   └── metainfo.xml
            ├── YARN/
            │   └── metainfo.xml
            ├── HIVE/
            │   └── metainfo.xml
            └── SPARK/
                └── metainfo.xml
```

## 5. 核心文件说明

### 5.1 Stack metainfo.xml

Stack 级别的 `metainfo.xml` 用于描述 Stack 名称、版本、父子关系和基础属性。

### 5.2 repoinfo.xml

`repoinfo.xml` 用于描述组件包仓库地址，通常与 Bigtop 产出的 yum/apt 仓库对应。

### 5.3 Service metainfo.xml

每个服务目录下的 `metainfo.xml` 用于定义：

- 服务名称
- 服务显示名称
- 服务版本
- 服务组件
- Master / Slave / Client 角色
- 启动脚本
- 配置依赖
- 服务检查

### 5.4 package/scripts

后续每个服务应补充控制脚本，例如：

```text
package/scripts/
├── service_check.py
├── namenode.py
├── datanode.py
├── resourcemanager.py
└── nodemanager.py
```

## 6. 与 Bigtop 的关系

Bigtop 负责构建 Hadoop 生态组件包，自定义 Ambari Stack 负责描述这些包如何被 Ambari 安装与管理。

```text
Bigtop Packages
      |
      v
Repository / repoinfo.xml
      |
      v
Ambari Stack / Service Definition
      |
      v
Ambari Install / Start / Monitor
```

## 7. 与 Blueprint 的关系

Stack 定义“有什么服务、组件和配置”，Blueprint 定义“怎么部署这些服务”。

| 对象 | 作用 |
|---|---|
| Stack | 定义服务类型、组件、配置、脚本 |
| Repository | 定义软件包来源 |
| Blueprint | 定义集群拓扑和组件分布 |
| Host Mapping | 定义具体主机绑定 |

## 8. 演进路线

### 第一阶段：Stack 骨架

- 新增 `BIGDATA/1.0` Stack 目录
- 新增 Stack `metainfo.xml`
- 新增 `repoinfo.xml` 模板
- 新增 HDFS / YARN / HIVE / SPARK 服务 metainfo 骨架

### 第二阶段：服务脚本

- 为 HDFS 补充 NameNode / DataNode 控制脚本
- 为 YARN 补充 ResourceManager / NodeManager 控制脚本
- 为 HIVE 补充 HiveServer2 / Metastore 控制脚本
- 为 SPARK 补充 History Server 控制脚本

### 第三阶段：配置定义

- 补充 `configuration/` 目录
- 补充默认配置 XML
- 与 `ambari/configs/` 中的配置模板打通

### 第四阶段：安装验证

- 接入 Blueprint
- 使用本地 Bigtop repo 安装
- 执行 Ambari service check
- 执行 smoke test

## 9. 后续待办

- [ ] 补充 Stack 服务控制脚本
- [ ] 补充 configuration XML
- [ ] 补充 package 依赖声明
- [ ] 补充 stack advisor
- [ ] 补充 Ambari 安装验证 runbook
