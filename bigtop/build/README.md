# Bigtop Build 验证入口

## 1. 目录目标

本目录用于沉淀 Phase 1 的 Bigtop 构建验证资产。

当前目标不是直接提供完整生产构建脚本，而是先定义构建验证入口、检查项和后续脚本落点。

## 2. 构建基线

| 项目 | 值 |
|---|---|
| OS | Ubuntu 22.04 |
| JDK | JDK 8 |
| Bigtop | 3.5.0 |
| 包格式 | DEB |
| 仓库类型 | apt |

## 3. 构建范围

Phase 1 P0 组件：

- Hadoop 3.5.0
- ZooKeeper 3.9.5
- Hive 4.2.0
- Hive Standalone Metastore 4.2.0
- Tez 0.10.5
- Spark 3.5.8
- HBase 2.5.14

## 4. 后续文件规划

```text
bigtop/build/
├── README.md
├── build-plan.md          # 构建计划与步骤
├── env.md                 # 构建环境要求
├── component-builds.md    # 各组件构建结果记录
└── scripts/               # 后续脚本目录，占位
```

## 5. 关联检查表

- `docs/checklists/p1-012-bigtop-build-validation-checklist.md`

## 6. 关联 Issue

- P1-012 执行 Bigtop 3.5.0 构建验证
