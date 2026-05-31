# ADR-001 平台定位

## 状态

Accepted

## 背景

Architecture Review #1 指出，当前文档已经从 Ambari + Hadoop 集群设计演进为 Bigdata Platform 设计，但仍存在一个风险：后续 Blueprint、Lifecycle、Management Backend 设计容易重新回到 Ambari 中心化视角。

需要通过 ADR 固化平台定位，避免后续设计偏移。

## 决策

Bigdata Platform 不是 Ambari 二次开发项目，也不是单纯 Hadoop 发行版，而是一套面向传统数仓、实时数据湖和多种部署形态的大数据平台产品。

平台核心职责包括：

- Stack 定义与版本治理
- Service Pack 扩展模型
- Artifact Repository 制品管理
- Release 发布与交付管理
- Deployment Blueprint 部署建模
- Lifecycle 生命周期管理
- Management Backend 适配
- 组件验证、运维和回滚体系

Ambari 是 Phase 1 的默认 Management Backend，不是平台核心。

## 影响

后续所有设计必须围绕 Bigdata Platform，而不是围绕 Ambari。

正确方向：

```text
Bigdata Platform
  -> Platform Core
  -> Engines
  -> Artifact Layer
  -> Backend Adapters
```

错误方向：

```text
Ambari Platform
  -> Hadoop Services
```

## 后续要求

- 新增 Platform Core 设计
- 新增 Backend Adapter 设计
- Blueprint 必须定义为 Deployment Blueprint，而不是 Ambari Blueprint
- Release 必须作为对外交付单元
