# 安全设计

## 1. 文档目标

本文档定义 Bigdata Platform 的安全设计基线、第一阶段安全边界和后续安全治理演进路线。

第一阶段已确认：Kerberos 设计保留，但不默认启用。

## 2. 安全设计原则

- 默认最小权限
- 服务账号独立
- 管理账号可审计
- 配置与密钥分离
- 生产环境预留 Kerberos 启用路径
- 后续引入 Ranger / Knox / Atlas 等治理组件

## 3. 第一阶段安全范围

第一阶段聚焦传统数仓物理机 HA 底座，安全范围包括：

- 主机访问控制
- Ambari 管理账号
- 服务运行账号
- SSH 与 sudo 策略
- 文件目录权限
- 包仓库访问权限
- Kerberos 后续启用路径设计

第一阶段不默认启用：

- Kerberos
- Ranger
- Knox
- Atlas
- 统一身份认证集成

## 4. 主机安全

### 4.1 OS 基线

目标 OS：Ubuntu 22.04。

需要定义：

- 主机名规范
- 用户和用户组规范
- SSH 登录策略
- sudo 权限策略
- 时间同步
- 防火墙策略
- 系统日志保留策略

### 4.2 节点访问

建议区分：

| 账号类型 | 用途 |
|---|---|
| 管理账号 | 运维登录、安装、巡检 |
| 服务账号 | Hadoop / Hive / Spark / HBase 等服务运行 |
| 只读账号 | 巡检、审计、查询 |

## 5. Ambari 安全

Ambari 作为传统大数据长期管理面，需要重点保护：

- Web UI 访问
- REST API 访问
- 管理员账号
- Agent 通信
- Repository 配置权限
- 操作审计记录

第一阶段需要至少完成：

- Ambari admin 默认密码修改
- 管理账号分级
- 操作记录保留
- 内网访问限制

## 6. 服务账号设计

建议至少预留以下服务账号：

| 账号 | 用途 |
|---|---|
| hdfs | HDFS 服务 |
| yarn | YARN 服务 |
| mapred | MapReduce History 服务 |
| hive | Hive Metastore / HiveServer2 |
| spark | Spark History Server / Spark Client |
| hbase | HBase Master / RegionServer |
| zookeeper | ZooKeeper 服务 |
| ambari | Ambari Server / Agent 相关 |

## 7. Kerberos 设计保留

第一阶段不默认启用 Kerberos，但需要保留后续启用路径。

### 7.1 后续启用条件

当平台进入生产安全要求较高的场景时，应启用 Kerberos。

触发条件：

- 多租户访问
- 生产数据安全要求
- 数据权限隔离
- 审计要求
- 与 Ranger 集成

### 7.2 Kerberos 影响范围

启用 Kerberos 会影响：

- HDFS 访问
- YARN 任务提交
- Hive 查询
- Spark 作业
- HBase 访问
- Ambari 服务管理
- 客户端配置

### 7.3 设计预留

第一阶段文档和配置应预留：

- principal 命名规范
- keytab 管理目录
- krb5.conf 分发策略
- 服务账号映射
- 客户端认证方式

## 8. 包仓库安全

Bigtop 包仓库需要考虑：

- 内网访问控制
- 仓库只读发布
- 包版本不可变
- 仓库快照
- 回滚能力
- 包来源记录

第一阶段可先不强制 GPG 签名，但应在后续阶段引入。

## 9. 数据访问安全

第一阶段默认基于 Hadoop 文件权限和服务账号管理。

后续需要扩展：

- Kerberos
- Ranger 权限策略
- Hive 表级权限
- HBase 表/列族权限
- 审计日志

## 10. 后续安全治理路线

| 阶段 | 能力 |
|---|---|
| Phase 1 | 主机安全、账号规范、Kerberos 设计保留 |
| Phase 2 | Kerberos 可选启用、操作审计增强 |
| Phase 3 | Ranger / Knox / Atlas 进入设计 |
| Phase 5 | Kubernetes RBAC / Secret / NetworkPolicy |

## 11. 验收标准

第一阶段安全验收包括：

- 管理账号和服务账号清单完整
- Ambari 默认密码已变更
- SSH 访问策略明确
- 服务目录权限规范明确
- Kerberos 后续启用路径明确
- 包仓库访问策略明确

## 12. 后续待办

- [ ] 补充账号权限矩阵
- [ ] 补充目录权限矩阵
- [ ] 补充 Kerberos 启用方案
- [ ] 补充 Ranger 集成设计
- [ ] 补充包仓库签名方案
