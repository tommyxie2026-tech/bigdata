# Bigdata Platform Environment 设计

## 1. 文档目标

本文档定义 Bigdata Platform 的 Environment 抽象、Environment Profile、操作系统模型、运行时模型、包管理模型、部署目标模型、兼容性矩阵和与 Stack、Service Pack、Artifact Repository、Deployment Intent 的关系。

Environment 是 Foundation Layer 的基础声明模型，用于表达平台运行在哪里、使用什么系统环境、使用什么运行时和制品格式。

## 2. 背景

当前多个文档中直接出现：

```text
Ubuntu 22.04
JDK 8
apt
bare-metal
```

这些信息不应散落在 Stack、Service Pack、Release 或验证计划中，而应该统一抽象为 Environment Profile。

这样未来支持：

```text
Ubuntu 24.04
Rocky Linux 9
JDK 17
VM
Kubernetes
RPM / Yum
Container Image
```

时，不需要重写 Stack 或 Capability。

## 3. Environment 定义

Environment 表示平台运行和交付所依赖的基础环境。

```text
Environment = OS + Runtime + Package System + Deployment Target + Resource Model + Network Model
```

Environment 不表达“需要什么能力”，也不表达“用什么组件实现”。

- Capability 表达需要什么能力
- Stack 表达用哪些组件实现
- Environment 表达在哪种环境运行
- Deployment Intent 表达部署成什么规模和拓扑

## 4. Environment Profile

Environment Profile 是可复用的环境声明。

命名建议：

```text
<os>-<runtime>-<target>
```

示例：

| Profile | 说明 |
|---|---|
| ubuntu22-jdk8-baremetal | BIGDATA-1.0 默认物理机环境 |
| ubuntu22-jdk8-vm | Ubuntu 22.04 + JDK 8 虚拟机环境 |
| ubuntu22-jdk17-vm | JDK 17 兼容性评估环境 |
| rocky9-jdk17-vm | 未来 RPM/Yum 体系评估环境 |
| k8s-container | 未来 Kubernetes 容器运行环境 |

## 5. BIGDATA-1.0 默认 Environment

```yaml
environmentProfile: ubuntu22-jdk8-baremetal
os:
  family: ubuntu
  version: "22.04"
runtime:
  jdk: 8
packageSystem:
  type: deb
  manager: apt
deploymentTarget:
  type: bare-metal
```

## 6. 操作系统模型

OS 模型用于表达发行版、版本和包体系。

```yaml
os:
  family: ubuntu
  version: "22.04"
  arch: x86_64
```

未来扩展：

```yaml
os:
  family: rocky
  version: "9"
  arch: x86_64
```

OS 模型影响：

- 包格式
- 包管理器
- systemd 行为
- 默认目录
- 用户权限
- 内核参数
- 文件句柄限制
- 网络配置方式

## 7. Runtime 模型

Runtime 模型用于表达 JDK、Python、Scala 等运行时。

BIGDATA-1.0 默认：

```yaml
runtime:
  jdk: 8
```

兼容性评估：

```yaml
runtime:
  jdk: 17
```

Runtime 影响：

- 构建兼容性
- 服务启动
- 客户端命令
- 反射和模块化限制
- Spark / Hive / HBase 兼容性

## 8. Package System 模型

BIGDATA-1.0 默认：

```yaml
packageSystem:
  type: deb
  manager: apt
  repository: bigtop-3.5.0-ubuntu22
```

未来扩展：

```yaml
packageSystem:
  type: rpm
  manager: yum
  repository: bigtop-rocky9
```

容器形态：

```yaml
packageSystem:
  type: image
  registry: harbor
```

## 9. Deployment Target 模型

Deployment Target 表达运行载体。

BIGDATA-1.0：

```yaml
deploymentTarget:
  type: bare-metal
```

近期扩展：

```yaml
deploymentTarget:
  type: vm
```

远期扩展：

```yaml
deploymentTarget:
  type: kubernetes
  distribution: generic
```

Deployment Target 决定：

- Backend Adapter 选择
- Blueprint 转换方式
- 网络模型
- 存储模型
- 资源调度方式
- 生命周期执行方式

## 10. Resource Model

Resource Model 描述节点资源要求。

示例：

```yaml
resources:
  master:
    cpu: 8
    memory: 32Gi
    disks:
      - type: system
      - type: data
  worker:
    cpu: 16
    memory: 64Gi
    disks:
      - type: data
        count: 4
  gateway:
    cpu: 4
    memory: 16Gi
```

BIGDATA-1.0 当前只定义建议，不做自动资源调度。

## 11. Network Model

Network Model 描述网络约束。

示例：

```yaml
network:
  dnsRequired: true
  ntpRequired: true
  sshRequired: true
  firewallPolicy: controlled
```

需要覆盖：

- 主机名解析
- SSH 连通
- NTP 时间同步
- 服务端口
- 防火墙策略
- 多网卡或管理网隔离

## 12. Environment 与 Stack 的关系

Stack 不应直接绑定 OS/JDK，而应声明支持的 Environment Profile。

示例：

```yaml
stack: BIGDATA-1.0
supportedEnvironments:
  - ubuntu22-jdk8-baremetal
  - ubuntu22-jdk8-vm
  - ubuntu22-jdk17-vm-evaluation
```

这样未来新增环境时，只需扩展兼容矩阵。

## 13. Environment 与 Service Pack 的关系

Service Pack 需要声明对环境的要求。

示例：

```yaml
service: hbase
supportedEnvironments:
  - ubuntu22-jdk8-baremetal
  - ubuntu22-jdk8-vm
constraints:
  jdk:
    default: 8
    evaluation: 17
  packageSystem:
    - deb
```

## 14. Environment 与 Artifact Repository 的关系

Environment 决定 Artifact 类型。

| Environment | Artifact |
|---|---|
| ubuntu22-jdk8-baremetal | deb / apt repo |
| rocky9-jdk17-vm | rpm / yum repo |
| k8s-container | image / helm chart / operator bundle |

## 15. Environment 与 Backend Adapter 的关系

| Deployment Target | Backend Adapter |
|---|---|
| bare-metal | Ambari Adapter |
| vm | Ambari Adapter |
| kubernetes | Kubernetes Adapter |

BIGDATA-1.0 默认：

```text
ubuntu22-jdk8-baremetal -> Ambari Adapter
```

## 16. Compatibility Matrix

Environment Engine 需要维护兼容性矩阵。

示例：

```yaml
compatibility:
  hadoop:
    "3.5.0":
      supported:
        - ubuntu22-jdk8-baremetal
      evaluation:
        - ubuntu22-jdk17-vm
  spark:
    "3.5.8":
      supported:
        - ubuntu22-jdk8-baremetal
      evaluation:
        - ubuntu22-jdk17-vm
    "4.1.x":
      evaluation:
        - ubuntu22-jdk17-vm
```

状态建议：

```text
supported
evaluation
unsupported
unknown
```

## 17. Environment Engine 职责

Environment Engine 是 Platform Core 的一部分。

职责：

- 加载 Environment Profile
- 校验 OS/JDK/Package System/Target
- 校验 Stack 兼容性
- 校验 Service Pack 兼容性
- 选择 Artifact 类型
- 选择 Backend Adapter
- 输出 Environment Runtime Model

## 18. Environment Runtime Model

示例输出：

```yaml
environmentRuntime:
  profile: ubuntu22-jdk8-baremetal
  os: ubuntu22
  runtime: jdk8
  packageSystem: apt
  artifactType: deb
  backendAdapter: ambari
  deploymentTarget: bare-metal
```

## 19. BIGDATA-1.0 当前目标

BIGDATA-1.0 的 Environment 目标：

- 默认支持 Ubuntu 22.04 + JDK 8 + bare-metal
- 支持 VM 作为近期开拓目标
- JDK 17 只做兼容性评估
- Kubernetes 进入远期设计，不进入 Phase 1 实施
- DEB / apt 是 Phase 1 默认包体系

## 20. 当前不做事项

当前阶段不做：

- 多 OS 自动构建
- RPM/Yum 真实交付
- Kubernetes 真实部署
- 自动资源调度
- 跨云环境适配

当前目标是定义 Environment Model，为后续 Deployment Intent 和 Backend Adapter 设计提供基础。

## 21. 后续文档

建议继续补：

- `docs/deployment-intent-design.md`
- `docs/deployment-blueprint-design.md`
- `docs/backend-adapter-design.md`
- `docs/lifecycle-design.md`
