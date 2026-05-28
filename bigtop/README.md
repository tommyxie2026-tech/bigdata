# Bigtop 工程目录

本目录用于沉淀基于 Apache Bigtop 的大数据组件构建、包管理、版本矩阵、仓库发布和集成测试资产。

## 目录结构

```text
bigtop/
├── README.md
├── version-matrix.md
├── build/
│   └── build-packages.sh
├── repo/
│   ├── yum.repo.template
│   └── publish-local-repo.sh
└── tests/
    └── smoke-test.sh
```

## 与 Ambari 的关系

- Bigtop 负责构建和发布 Hadoop 生态组件包。
- Ambari 负责消费这些组件包，并完成集群安装、服务配置、服务启停、监控告警和运维管理。
- `bigdata` 仓库负责沉淀两者之间的配置、脚本、文档和验证流程。

## 标准流程

```text
Bigtop Build -> Package Repository -> Ambari Repository Config -> Cluster Install -> Service Check
```

## 后续计划

- 补充完整组件版本矩阵
- 接入实际 Bigtop 构建环境
- 支持 yum / apt 仓库发布
- 补充 Ambari 安装验证和 smoke test
