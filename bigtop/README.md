# Bigtop 工程验证目录

## 1. 目录目标

本目录用于承载 Bigdata Platform Phase 1 中与 Bigtop 真实构建体系相关的工程验证资产。

Phase 1 的 Bigtop 目标是：

```text
Ubuntu 22.04 + JDK 8 + Bigtop 3.5.0
  -> 构建 Hadoop / ZooKeeper / Hive / Tez / Spark / HBase DEB 包
  -> 发布 apt 仓库
  -> 供 Ambari Repository 消费
```

## 2. 子目录

```text
bigtop/
├── README.md
├── build/      # 构建环境、构建流程、构建任务说明
├── repo/       # apt 仓库发布、快照、回滚设计
├── patches/    # 针对组件或 Bigtop 的补丁占位
└── tests/      # 构建与仓库验证测试占位
```

## 3. 与 Ambari 的关系

- Bigtop 负责构建和发布 Hadoop 生态组件包。
- Ambari 负责消费这些组件包，并完成集群安装、服务配置、服务启停、监控告警和运维管理。
- `bigdata` 仓库负责沉淀两者之间的配置、脚本、文档和验证流程。

## 4. 标准验证流程

```text
Bigtop Build
  -> DEB Package
  -> apt Repository
  -> Ambari Repository Config
  -> Cluster Install
  -> Service Check
  -> Smoke Test
```

## 5. 当前阶段边界

当前只创建工程验证骨架，不提交重型构建脚本。具体脚本需要等待以下内容明确：

- Bigtop 3.5.0 构建能力验证
- 组件候选版本适配方式
- Ubuntu 22.04 DEB 包输出路径
- Ambari Repository 对接要求

## 6. 关联任务

- P1-012 执行 Bigtop 3.5.0 构建验证
- P1-016 执行 Phase 1 版本冻结评审

## 7. 关联文档

- `docs/bigtop-build-design.md`
- `docs/version-matrix.md`
- `docs/phase1-version-validation-plan.md`
- `docs/checklists/p1-012-bigtop-build-validation-checklist.md`
