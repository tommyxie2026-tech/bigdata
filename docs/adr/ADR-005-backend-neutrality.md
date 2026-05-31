# ADR-005 Backend Neutrality

## 状态

Accepted

## 背景

Architecture Review #6 指出，BIGDATA Platform 的长期目标不是构建一个 Ambari 二次开发项目，而是构建一套可面向传统数仓、实时数据湖、物理机、虚拟机和未来 Kubernetes 的通用大数据平台。

Ambari 可以作为 BIGDATA-1.0 的候选 Management Backend，但不应成为平台核心依赖。

如果平台核心直接绑定 Ambari，则未来会限制：

- 实时数据湖组件扩展
- Kubernetes / Operator 形态
- 自研管理后端
- 多种部署目标
- 长期生命周期控制

## 决策

BIGDATA Platform 必须保持 Backend Neutrality。

即：

```text
Platform Core 不绑定任何单一 Management Backend。
所有管理动作必须通过 Backend Adapter 执行。
```

Ambari 是 BIGDATA-1.0 的默认候选 Backend Plugin，而不是平台核心。

## 架构原则

### Principle 1: Platform Core 不直接依赖 Ambari

Platform Core 只处理平台声明、模型解析、依赖图、部署意图、生命周期计划和 Release 冻结。

### Principle 2: 所有执行动作通过 Backend Adapter

安装、配置、启动、停止、检查、升级、回滚等动作必须通过统一 Backend Adapter 接口执行。

### Principle 3: Ambari 只是默认实现

BIGDATA-1.0 可以优先验证 Ambari Adapter，但 Ambari Validation 失败不应导致平台架构崩溃。

### Principle 4: 允许多 Backend 并存

未来允许：

```text
Ambari Adapter
Native Adapter
Kubernetes Adapter
Custom Adapter
```

## 目标架构

```text
BIGDATA Platform
│
├── Foundation Layer
│   ├── Capability
│   ├── Environment
│   ├── Stack
│   ├── Service Pack
│   ├── Dependency Graph
│   └── Release
│
├── Platform Core
│   ├── Stack Engine
│   ├── Service Pack Engine
│   ├── Environment Engine
│   ├── Dependency Graph Engine
│   ├── Lifecycle Engine
│   └── Release Engine
│
├── Execution Layer
│   ├── Deployment Plan
│   ├── Lifecycle Plan
│   └── Validation Plan
│
└── Backend Plugins
    ├── Ambari Adapter
    ├── Native Adapter
    └── Kubernetes Adapter
```

## 对 BIGDATA-1.0 的影响

BIGDATA-1.0 仍可继续验证：

```text
Ambari 3.0.0
Ambari Metrics 3.0.0
Ambari Blueprint
Ambari Repository
Ambari Service Check
```

但这些属于 Ambari Adapter 路线，而不是平台核心路线。

如果 Ambari 3.0.0 不满足长期要求，可选择：

- 回退 Ambari 2.7.9
- 使用 Hybrid 模式
- 设计 Native Adapter
- 将 Ambari 降级为过渡工具

## 对 Bigtop 的影响

Bigtop 的定位不同于 Ambari。

Bigtop 负责：

- Build
- Package
- Repository
- Binary Artifact

这些能力即使脱离 Ambari 仍然有价值，因此 Bigtop 可以作为长期基础设施候选继续验证。

## 后果

正面影响：

- 平台不被 Ambari 锁定
- 未来可支持 Kubernetes / Native Backend
- Ambari Validation 失败不会推翻平台设计
- Backend Adapter 成为可替换插件

代价：

- 需要定义 Backend Adapter 接口
- 需要增加 Adapter 层验证
- 需要避免在 Service Pack 中写死 Ambari 语义
- Phase 1 文档需要统一修订措辞

## 后续动作

- 新增 Architecture Review #6
- 修订 Management Backend 相关文档
- 明确 Ambari 为 Backend Plugin
- 保留 Ambari Viability Review
- 后续补充 Backend Adapter Design
