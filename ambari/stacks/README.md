# Ambari Stacks

本目录用于存放 `bigdata` 项目的自定义 Ambari Stack 定义。

## 当前规划

```text
ambari/stacks/
└── BIGDATA/
    └── 1.0/
        ├── metainfo.xml
        ├── repos/
        │   └── repoinfo.xml
        └── services/
            ├── HDFS/
            ├── YARN/
            ├── HIVE/
            └── SPARK/
```

## 目标

- 定义 Bigdata 发行版 Stack
- 描述服务、组件、配置和脚本
- 对接 Bigtop 构建产出的 yum/apt 仓库
- 支持 Ambari Blueprint 自动化安装

## 注意

当前内容是 Stack 设计骨架，尚未包含完整生产可用的 Ambari service scripts、configuration XML 和 stack advisor。
