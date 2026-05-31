# ADR-002 管理后端定位

## 状态

Accepted

## 背景

Architecture Review #1 指出，Ambari 已被正确降级为 Management Backend，但相关文档仍存在 Ambari 中心化倾向。需要明确管理后端只是执行适配层，不是平台核心。

## 决策

Ambari 是 BIGDATA-1.0 的默认 Management Backend，用于物理机和虚拟机形态下的传统 Hadoop 生态管理。

Ambari 的职责：

- 主机注册
- Repository 配置
- 服务安装
- 配置下发
- 服务启停
- Service Check
- 告警与指标展示

Ambari 不负责定义平台核心抽象。以下能力应由 Platform Core 负责：

- Stack 解析
- Service Pack 解析
- Dependency Graph 计算
- Deployment Blueprint 生成
- Lifecycle 编排
- Release 管理
- Artifact 版本治理

## 后续演进

未来管理后端可以包括：

```text
Ambari Adapter
Kubernetes Adapter
Custom Console Adapter
Future Adapter
```

## 影响

后续文档必须使用 Management Backend Adapter 视角描述 Ambari，避免把 Ambari 作为平台核心。
