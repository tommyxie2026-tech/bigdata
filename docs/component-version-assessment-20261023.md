# 大数据平台版本与架构升级评估

评估日期：2026-10-23；目标与 Java 矩阵更新：2026-10-24，见[最新目标矩阵图](target-version-matrix-20261024.md)。仓库实现基线：`a3e673b8e5a9671afaa29310c3dd84eb323c7dde`。

本文是选型评估，不修改当前版本锁定、RPM、服务配置或发布状态。现有交付以[版本矩阵](version-matrix.md)、[组件矩阵](component-matrix.md)和[路线图](product-roadmap.md)为准。下文所有新组合均为待回归候选，不是已认证的生产组合。上游动态下载页面可能继续变化，实施时需重新核验并冻结 tag、源码 SHA、依赖、镜像摘要和 checksum。

## 1. 结论与建议

建议下一代采用 **Iceberg 为默认表格式、REST Catalog 为共享元数据入口、Trino 为交互查询入口、Spark 为批处理、Flink 为流处理**。允许退出部分组件后，不再让所有引擎迁就三套湖仓和传统 Hive 执行栈。Hudi、Paimon 按实际业务需求成为独立可选配置；传统 Ambari/Hadoop 集群保留兼容方案。

建议优先验证的现代组合是：**Spark 4.1.3 / Scala 2.13、Flink 2.2.1、Flink CDC 3.7.0、Iceberg 1.12.0、Trino 484、Kafka 4.3.1、Polaris 1.8.0**。Superset 6.1.0 作为 SQL/BI 界面候选。这里选择的是有官方适配入口的交集，而非把各项目最大版本号直接拼在一起。[S04][S06][S07][S09][S10][S15][S16]

当前组件并非全部停留在三年前：Hadoop 3.4.3、Iceberg 1.12.0、Hudi 1.2.1、Paimon 2.1.0 都有近期上游发行。突出问题是 Kafka 3.4.1 较旧、Hue 使用开发快照，以及运行时、连接器和元数据的组合约束。升级应同时减少维护面，而不是再增加一套全量组件。**Hadoop 安全基座不因传统栈可选而延后：需要 Hadoop 的配置以 3.5.0 / JDK 17 为优先升级候选，3.4.3 仅保留迁移对照与有时限回退。**

“最新稳定”分为三层：上游正式发行、官方列出的适配范围、本平台真实回归。前两层只能支持候选选择，最后一层通过后才能冻结生产版本。

## 2. 每个现有组件的版本评估

“兼容方案”用于确有传统集群需求的场景，不等于要求全部组件继续进入默认安装。未单列日期的版本，只确认发行版本，不以归档文件时间推断正式发布日期。

| 组件 | 当前锁定 | 已核验上游正式版本 / 特殊标注 | 建议与处置 | 来源 |
|---|---|---|---|---|
| Ambari | 3.0.0 | 3.0.0 | 传统管理可选；不作为现代栈升级前提 | S01 |
| Bigtop | 3.6.0 | 3.6.0 | 保留 RPM 构建能力；现代组件独立配方，不受 BOM 统一版本限制 | S02 |
| Bigtop common | 3.6.0 | 随 Bigtop，不是独立上游产品版本 | 仅被依赖的 RPM 安装 | S02 |
| ZooKeeper | 3.8.4 | current 3.9.6；官方 stable 3.8.7，均为 2026-09-15 | 传统配置优先验证 3.8.7；现代 Kafka 不再依赖它 | S03 |
| Hadoop / HDFS / YARN | 3.4.3 | 3.5.0，2026-04-02；3.4.3 为 2026-02-24 | 优先评估升级 3.5.0 / JDK 17；3.4.3 仅作迁移对照与有时限回退；现代 S3 路径仍审计内嵌客户端 | S05 |
| Hive / Metastore | 4.0.1 | 4.2.1，2026-08-24 | 现代 Iceberg 路径转 REST Catalog；传统 Hive 4.2.1 单独评估 JDK 21 与配套 Hadoop | S08 |
| Tez | 0.10.5 | 0.10.5，2025-05-30 | 已是最新；随 Hive 执行配置可选，退出现代默认栈 | S11 |
| Spark | 3.5.8 | 4.2.0，2026-07-14；另有 4.1.3、3.5.9 | 现代候选 4.1.3；传统补丁候选 3.5.9；暂不选缺少湖仓运行时配套的 4.2.0 | S04 |
| HBase | 2.6.5 | 最新 GA 3.0.0，2026-08-05；2.6.7，2026-10-01；下载页 stable 标注为 2.5.16 | 无在线宽表业务则退出默认栈；传统候选 2.6.7，不为 stable 标签倒退版本；3.0 独立迁移 | S12 |
| Kafka | 3.4.1 | 4.3.1，2026-06-25，受支持发行 | 现代候选 4.3.1 / KRaft / JDK 17+；必须验证连接器协议、权限与恢复 | S06 |
| Flink | 1.20.1 | 最新稳定 2.3.0，2026-06-25；可用 2.2.1；LTS 1.20.5 | 现代候选 2.2.1；传统全格式候选 1.20.5 | S07 |
| Flink CDC MySQL | 3.4.0 | 3.7.0，2026-10-10 | 候选 3.7.0；SQL/DataStream 与 Pipeline 包分别核验，不能混用 | S07 |
| Flink CDC PostgreSQL | 3.4.0 | 3.7.0，2026-10-10 | 同上；增加源库支持版本、槽位和恢复验收 | S07 |
| Trino | 483 | 484，2026-10-15 | 现代候选 484；如果保留 Hudi 插件则暂留其明确适配的 483 | S09、S13 |
| Iceberg | 1.12.0 | 1.12.0，2026-09-29 | 保留，作为默认格式；升级引擎时更换匹配 runtime，不必升级表格式版本号 | S10 |
| Hudi | 1.2.1 | 1.2.1，2026-09-24 | 特定增量/更新场景可选；退出默认 Flink 2.2 链路，避免阻塞全栈升级 | S13 |
| Paimon | 2.1.0 | 2.1.0，2026-10-12 | 实时主键表场景可选；可与 Flink 2.2 评估，不默认维护第二套全链路 | S14 |
| Hue | 自报 4.11.0，开发快照 | 官方稳定标签 4.11.0；发布公告 2023-01-23 | 新平台不默认引入；SQL/BI 入口评估 Superset；旧 Hue 独立维护 | S17 |
| Ambari Metrics | 3.0.0 | 已核验独立 release-3.0.0；最新正式独立发行日期未确认 | 随传统 Ambari 可选；现代监控走独立采集方案，不直接重用其内嵌存储 | S18 |
| Hadoop S3A AWS SDK | 2.35.4 | SDK 上游已到 2.57.3；Hadoop 3.4.3 明确配套 2.35.4 | 保留 Hadoop 配套版本，不能单独追 SDK 最新；Iceberg S3 FileIO 独立管理依赖 | S05、S19 |

### 关键运行时边界

- Ambari 3 使用 JDK 17，不意味着 Metrics Collector 也能切到 17。当前 Metrics 有自己的旧 HBase/Phoenix 和 JDK 8 依赖，需要独立维护或退出。
- Hadoop 3.5 的服务端转向 Java 17；3.4 的构建/运行要求不同。Hive 4.2.1 最低 JDK 21；不能继续以全局 JDK 8 统一管理。[S05][S08]
- Spark 4 转 Scala 2.13，现有 Scala 2.12 runtime 不可复用。Spark 4.2 支持的运行时和 Python 最低版本也不代表旧脚本兼容；新基线需选择仍受维护的 Python 分支，不能只满足最低版本。[S04]
- Flink 2.x 优先按 Java 17 验证；Trino 484 需要 Java 25。各服务分别绑定运行时，JDK 补丁和 checksum 实施时重新锁定。[S07][S09]
- 当前 openEuler 22.03 LTS SP4 的 RPM 交付不能外推为新运行时可安装。OS、glibc、Python 和 JDK 仓库支持另设验收；不把“最新创新版”误当长期支持版。[S20]

## 2A. Hadoop 3.4.3 → 3.5.0 安全升级专项

### 评估结论

**建议推进 3.5.0 的独立验证，优先级高于仅维持 3.4.3 的兼容优化。** 截至 2026-10-23，官方最新稳定版为 3.5.0，发布日期 2026-04-02。升级目标同时覆盖 Hadoop 服务端、客户端与实际交付依赖；不把现代 S3 架构视为可以忽略 Spark/Flink 等进程内 Hadoop JAR 的理由。[S05][S21]

3.5.0 的官方说明明确包含第三方依赖 CVE 修复，但也承认有依赖尚未升级到最新。因此本评估支持升级方向，**尚未证明当前 RPM 的漏洞数量、所有可利用路径或升级后的剩余风险已清零**。需要对实际安装包出具扫描与适用性结论，不能只比较版本号。[S21]

### 安全证据与判定边界

| 风险层 | 已核验证据 / 当前结论 | 升级验收要求 |
|---|---|---|
| Hadoop 自身公告 | CVE-2025-27821 影响 3.2.0–3.4.1，修复于 3.4.2；不能计为 3.4.3 未修复漏洞 | 按每个 CVE 官方影响范围、源码补丁与实际二进制核验，记录适用或不适用依据 |
| 历史本地提权 | CVE-2023-26031 影响 3.3.1–3.3.4，修复于 3.3.5 | 审计实际 container-executor 的来源、RPATH、所有权与权限，不照搬旧版本扫描结论 |
| 第三方 Java 依赖 | 3.5.0 官方明确升级多项依赖以处理 CVE，同时说明有兼容原因未全部更新 | 对 3.4.3 与候选 3.5.0 的实际 RPM 生成 SBOM，比较嵌套/ shaded JAR、版本与加载路径 |
| JDK / native / OS | Hadoop 版本号不覆盖 JDK、libcrypto、压缩库及系统包风险 | 对实际 JDK 17 补丁、原生库与 OS 包分别扫描，保留厂商回补证据 |
| 配置与暴露面 | 软件更新不会自动启用认证、加密和正确授权 | 验证 Kerberos、HTTP SPNEGO/TLS、代理用户 ACL、服务权限、凭据与接口暴露范围 |

前两项仅是说明正确归因的方法，不是完整漏洞清单；依据为官方 [Hadoop CVE 列表](https://hadoop.apache.org/cve_list.html)。未取得现有部署扫描报告前，不编造“尚有多少高危”。依赖漏洞需要记录 CVE、包坐标、实际路径、修复版本、运行/测试作用域、可达性与处理决定；误报也必须有证据，不能直接过滤。[S22]

### 升级对生态的实际影响

| 边界 | 3.5.0 变更 / 风险 | 处理方式 |
|---|---|---|
| Java 与打包 | 服务端要求 Java 17；客户端支持 17/21。当前 catalog 默认 JDK 8 不能直接沿用 | 单独修改 Hadoop 构建、systemd、Ambari 服务环境、native 构建；不全局替换其他组件 JDK |
| HDFS / HA | RPC、元数据与故障恢复兼容必须实测 | 备份 fsimage/edits 与配置；验证 QJM/ZKFC、切主、读写校验、块报告与旧客户端接入 |
| YARN / MapReduce | JVM、容器执行器、调度和历史服务均在升级范围内 | 实际提交 MR/Spark/Flink 作业；验证队列/ACL、日志、容器隔离及 NodeManager 重启恢复 |
| Hive / Tez | 上游配套 Hadoop 版本与本仓库新组合不同；不能宣称自动兼容 | 以实际保留版本验证元数据访问、DDL/DML、Tez 作业及身份传递；失败再升级或退出对应配置 |
| HBase / Metrics | 在线 HBase 与 Metrics 内嵌 HBase 是不同依赖树 | 分别验证 WAL、恢复、权限与 JDK；不能用服务器升级替换内嵌库就算完成 |
| Spark / Flink / 湖仓 | 只升级 HDFS 服务端不会移除客户端进程中的旧 Hadoop 依赖 | 对分发包及插件 classpath 扫描；验证 RPC、token、HDFS/S3 读写；避免盲目覆盖 shaded JAR |
| S3A / AWS SDK | 3.5.0 release tag 的 POM 仍指定 SDK v2 2.35.4 | 不为了升级版本号强塞最新 SDK；重新验收 TLS、multipart、凭据续期、拒绝访问与重启读取 |
| 文件系统入口 | 3.5 移除 WASB，改用 ABFS | 清点 URI 与历史配置；存在 wasb/wasbs 数据路径时制定转换与读写回归 |
| Bigtop / Ambari | 现有 3.6 BOM 和服务定义不等于已适配 Hadoop 3.5 | 独立维护构建补丁和服务适配，保留许可证、源码及兼容 identity 证据 |

SDK 数值来自 [3.5.0 tag 的项目 POM](https://raw.githubusercontent.com/apache/hadoop/rel/release-3.5.0/hadoop-project/pom.xml)，是源码依赖基线，不代替最终 effective POM、依赖树与交付 SBOM。Hadoop 服务器与每个引擎客户端可采用经验证的不同版本；同样不能仅凭协议互通而接受仍含未处置高危依赖的客户端。[S23]

### 可执行的验证与发布顺序

1. **建立风险台账**：收集现有 3.4.3 安装清单、JDK/OS 版本和扫描报告；在 CI 的实际 RPM 解包目录生成 CycloneDX/SPDX SBOM，包含 native 与嵌套 JAR。扫描数据库日期和工具版本随证据冻结，不在本地下载大型 RPM。
2. **只构建必要候选**：建立 3.5.0 / JDK 17 独立配方，源码 tag/SHA、补丁和依赖均锁定；保留旧包。版本和构建输入变化意味着必须新构建 Hadoop；其他包仅在构建或兼容输入变化时重建。
3. **先小后大回归**：干净 openEuler 安装及 native 检查 → HDFS/YARN/MR → HA/安全身份 → Spark/Flink 客户端 → 实际保留的 Hive/Tez/HBase → S3A 与湖仓专项。每步独立有界超时和日志，失败只重跑相关层。
4. **比较安全收益**：输出新旧 SBOM 差异、已修复/残留/不适用 CVE；已确认可利用的 critical/high 项在发布前修复或具备明确缓解、负责人和期限，不用泛化忽略清单绕过。
5. **试点再晋级**：校验真实数据与恢复时长、旧客户端兼容和回退演练；通过后独立 RC/晋级 PR，核验 RPM/checksum/metadata，再更新冻结矩阵。当前文档不触发构建或发布。

回退需依据 3.5 的版本化升级文档，区分 upgrade、rollback、downgrade；在完成回退演练前不 finalize。备份不是自动回滚保证，不能用旧 RPM 直接覆盖新版本数据目录。实施前核对旧/新元数据、客户端和 JDK 的组合支持范围；若存在已确认可利用漏洞，3.4.3 回退只能是有时限、隔离且有补救措施的应急方案。[S24]

## 3. 为什么不能所有组件都选最大版本号

下表是本轮官方发布物/兼容表中列出的相关版本子集，不是平台已测矩阵。“未列出”应阻止默认选型，不能解释为已经证明技术上绝对不可能。

| 配套项目 | 已列出的相关 Flink 版本 | 已列出的相关 Spark 版本 | 影响 |
|---|---|---|---|
| Flink CDC 3.7 | 1.20、2.2 | 不适用 | 不能默认配 Flink 2.1 或最新 2.3 |
| Iceberg 1.12 | 1.20、2.1、2.2、2.3 | 3.5、4.0、4.1 | Spark 4.2 缺少列出的 runtime |
| Hudi 1.2.1 | 1.20、2.0、2.1 | 3.5、4.0、4.1 | 与 CDC 的共同 Flink 版本只有 1.20 |
| Paimon 2.1 | 1.20、2.0、2.1、2.2 | 3.5、4.0、4.1 | 可进入 Flink 2.2 可选配置；Spark 4 使用 Scala 2.13 |
| Flink Kafka connector 5.0.0 | 2.1、2.2 | 不适用 | broker、连接器、Flink 是三个版本维度 |

来源：[S07][S10][S13][S14]。因此，**保留三种格式和 CDC 的共同 Flink 版本只能先选 1.20；移出 Hudi Flink 配置后可评估 2.2**。Spark 4.1.3 则有三种格式共同的适配入口。Kafka 4.3.1 与具体 connector 的认证、事务、故障恢复仍需实测。

另有四项不能靠升级版本号解决的约束：

1. Spark 3.5 文档中的外部 Hive Metastore 支持范围止于 3.1.3，不能把当前 Hive 4 服务直接当成其已认证共享 catalog；Hive 3 又已结束维护，不建议为了迁就 Spark 新建 Hive 3 长期基线。[S04][S08]
2. Hive 4 的 Iceberg 集成与独立 Iceberg runtime 不是同一条发行线；替换任意 JAR 不能视为完成适配。[S10]
3. Hudi 1.2.1 的新 Trino 插件基于 Trino 483；Paimon 的 Trino 插件也有独立适配范围。Trino 最新版本不能代表三个格式全部可查询。[S13][S14]
4. Hudi 的 Spark 4.1 VARIANT 读取存在官方记录的限制/规避项；采用该配置须增加专项验证，不能以启动成功代替数据正确性。[S13]

## 4. 三种方案比较

| 方案 | 收益 | 代价与风险 | 结论 |
|---|---|---|---|
| A：原栈补丁升级，保留全部组件 | 改动范围较小，保留已建设能力 | 多套目录/运行时长期并存；Flink 被共同交集限制；旧 UI 和监控维护成本仍在 | 仅作存量兼容线 |
| B：Iceberg 默认，现代引擎与 REST Catalog | 减少重复格式和 Hive 耦合，可推进 Spark 4 / Flink 2 | 需验证目录迁移、权限、对象存储和新的运维方式 | **推荐下一代默认线** |
| C：各组件全部使用最新 GA | 单项功能最新 | Spark 4.2、Flink 2.3 与若干连接器没有共同配套；组合风险最高 | 暂不冻结，只作试验线 |

### 推荐默认线与可选能力

| 能力 | 默认候选 / 处理 | 状态与进入条件 |
|---|---|---|
| 表格式 | Iceberg 1.12.0 | 当前版本保留；需验证新引擎 runtime 与并发写入 |
| 批处理 | Spark 4.1.3 / Scala 2.13 | 候选；SQL 语义、ANSI、UDF 和历史数据回归 |
| 流处理 / CDC | Flink 2.2.1 + CDC 3.7.0 | 候选；checkpoint/savepoint、增删改、源端断连恢复 |
| 消息 | Kafka 4.3.1 / KRaft | 候选；客户端及连接器事务/权限回归 |
| 交互查询 | Trino 484 | 候选；默认仅承诺待测 Iceberg 路径 |
| 共享目录 | 新增 Polaris 1.8.0 / Iceberg REST | 候选；持久化、OAuth/OIDC、授权和凭据续期验收 |
| SQL / BI | 新增 Superset 6.1.0 | 候选；Trino 驱动、认证、取消查询和权限隔离验收；排除 7.0 RC |
| 存储 | 生产 S3 兼容服务或托管对象存储；HDFS 可选 | **尚未选定生产产品和版本**；不把 SeaweedFS 4.48 测试 fixture 当生产交付 |
| 实时主键表 | Paimon 2.1.0 可选 | 有明确业务再接入；独立验证跨引擎读写，不默认承诺 Trino 插件 |
| Hudi | 1.2.1 独立可选 | 不进入默认 Flink 2.2 配置；保留已有数据读取与导出能力 |
| Hive / Tez | 退出默认安装 | 存量 Hive SQL/表单独迁移；不能直接删除其数据与元数据 |
| Ambari / Metrics / HBase / ZooKeeper | 按存量需求可选 | 现代默认栈不依赖完整传统管理链；HBase 在线业务必须另评估替代能力 |
| 部署与观测 | 独立部署、指标与日志方案 | 未冻结；不把已有 Ambari 管理能力视为自动覆盖新组件 |

### 新增组件的适配理由

Polaris 1.8.0 于 2026-09-28 正式发行。Trino 使用 Iceberg REST catalog，Spark 可用 Iceberg 自带 REST 客户端接入；纯 Iceberg 路径不需要额外 Polaris Spark 扩展，因此其下载页专用 Spark 客户端的版本范围不应混作普通 REST 客户端限制。生产环境需持久化数据库，不能使用 quickstart 的内存存储。1.8 的数据库迁移也需要明确运维步骤。[S15]

Superset 6.1.0 是已核验稳定发行，7.0 RC 不选。它可提供 SQL Lab 和 BI，适合替代 Hue 的一部分 SQL 界面；**不能替代 Spark/Flink 作业管理、YARN 管理和文件浏览**。这些功能若仍需要，应单独设计入口。[S16]

推荐的数据路径为：

```text
MySQL / PostgreSQL → Flink CDC → Flink → Iceberg
Kafka → Flink → Iceberg
Spark ↔ Iceberg ← Trino ← Superset
          ↕
    Polaris REST Catalog
          ↕
  独立选定的对象存储
```

图中为职责关系，不表示数据经过 catalog 传输。存储读写与目录授权分别验收。官方集成指南支持这条技术路径，但没有证明上述精确版本组合已经完成本平台认证。已有非 Iceberg Hive/Hudi/Paimon 表也不会因部署 Polaris 自动转换。

## 5. 迁移顺序与验收门槛

1. **确定范围**：确认现代默认线及必须保留的业务，清点 Hive SQL、HBase 在线读写、Hudi/Paimon 表、Hue 作业入口；没有需求的组件不再加入默认构建矩阵。
2. **建立并行候选环境**：先验证 Polaris + Iceberg + Trino + Spark，再加入 Flink/CDC/Kafka。保留原 RPM 与目录，候选使用独立版本路径；无需等待旧全组件链完成后才开始测试。
3. **逐层证明正确性**：真实干净安装；认证与权限；精确数据行集；更新/删除；多引擎一致读取；并发提交；schema 演进；源端暂停后恢复；真实 checkpoint/savepoint；对象存储拒绝、重试与续期。
4. **验证生产运维**：catalog 数据库备份恢复、存储持久性、节点故障、重启、资源限额和可观测性；之后再进入七节点或新的部署拓扑验收。一次单节点 smoke 不能替代这些条件。
5. **迁移试点并冻结**：选少量真实工作负载，记录旧/新正确性与耗时、内存、恢复时长；通过后冻结版本、源码 SHA、运行时与兼容 identity，更新矩阵和路线图；未通过则保留兼容线。

CI 只对改变构建输入的包重新构建。测试脚本变动复用已验证 checksum/source/compatibility 的 RPM；引擎、Scala 或依赖发生变化时必须重新判断 runtime 包 identity，不能仅凭“表格式版本未变”复用旧集成包。安装、查询、网络、清理各自有超时并输出失败证据；不再用无界轮询掩盖错误。

### 回退边界

- catalog/元数据备份与数据备份分开，确认恢复后的表引用和对象路径仍有效。
- 新表协议、writer feature、schema 演进和存储布局可能不被旧 reader 支持；不能把切回旧 RPM 当成完整回退。
- Kafka 升级需先核验当前 KRaft metadata 版本与官方迁移路径；3.9.2 可作为特定迁移桥接，但已归档，不作为新长期基线。当前已采用 KRaft，不能武断声称必须先做 ZooKeeper 迁移。[S06]
- Flink 1.x → 2.x 状态和 savepoint 兼容需要专测；保留旧作业与恢复点，检查 connector 状态变化。
- 存量 HBase 不以 Iceberg 替代在线低延迟服务；业务需要时继续作为独立能力保留。

## 6. 本次不做与待决事项

本次只提交文档，不升级包、不删除组件、不触发全量构建、不自动合并。建议评审先决定默认线和存量必留能力，再将实际改造拆成引擎、catalog、UI 与业务迁移 PR。

尚待核验：生产对象存储产品/版本及支持模式；新部署面和监控栈；OS 支持窗口与新 JDK/Python 包可用性；精确 patch 组合；安全公告和依赖扫描；业务 SQL/UDF 与数据迁移成本。未核验项不写成“最新最稳定已通过”。

## 7. 官方来源

以下为本轮查阅入口；版本化页面优先，动态页面的核验时点为 2026-10-23。

- **S01 Ambari**：[3.0.0 说明](https://ambari.apache.org/docs/3.0.0/release-notes/)、[Bigtop 集成](https://ambari.apache.org/docs/3.0.0/ambari-dev/bigtop-guide/)。官方集成指南不等于本仓库全部版本经过认证。
- **S02 Bigtop**：[发行说明](https://bigtop.apache.org/release-notes.html)、[3.6.0 BOM](https://raw.githubusercontent.com/apache/bigtop/rel/3.6.0/bigtop.bom)。
- **S03 ZooKeeper**：[发行与 stable/current 标注](https://zookeeper.apache.org/releases/)、[公告](https://zookeeper.apache.org/news/)。
- **S04 Spark**：[公告](https://spark.apache.org/news/)、[4.2 文档](https://spark.apache.org/docs/4.2.0/)、[迁移说明](https://spark.apache.org/docs/latest/sql-migration-guide.html)、[3.5.9 Hive 集成](https://spark.apache.org/docs/3.5.9/sql-data-sources-hive-tables.html)。
- **S05 Hadoop**：[发行](https://hadoop.apache.org/releases.html)、[3.4.3 SDK 依赖](https://hadoop.apache.org/release/3.4.3.html)、[Java 兼容](https://cwiki.apache.org/confluence/spaces/HADOOP/pages/100827883/Hadoop+Java+Versions)。
- **S06 Kafka**：[受支持与归档版本](https://kafka.apache.org/community/downloads/)、[4.3 升级](https://kafka.apache.org/43/getting-started/upgrade/)、[Java](https://kafka.apache.org/43/operations/java-version/)。
- **S07 Flink / CDC**：[引擎和连接器下载矩阵](https://flink.apache.org/downloads/)、[CDC 兼容表](https://github.com/apache/flink-cdc#flink-version-compatibility)、[1.20 Java](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/deployment/java_compatibility/)。
- **S08 Hive**：[发行、JDK 与配套要求](https://hive.apache.org/general/downloads/)。
- **S09 Trino**：[484 发行](https://trino.io/docs/current/release/release-484.html)、[部署运行时](https://trino.io/docs/current/installation/deployment.html)、[REST catalog](https://trino.io/docs/current/object-storage/metastores.html)。
- **S10 Iceberg**：[发行](https://iceberg.apache.org/releases/)、[1.12 配套](https://iceberg.apache.org/blog/apache-iceberg-1.12.0-release/)、[Hive 集成](https://iceberg.apache.org/docs/latest/hive/)、[Spark catalog](https://iceberg.apache.org/docs/latest/spark-configuration/)。
- **S11 Tez**：[发行](https://tez.apache.org/releases/)、[安装](https://tez.apache.org/install.html)。
- **S12 HBase**：[下载和 stable 标注](https://hbase.apache.org/downloads/)。
- **S13 Hudi**：[发行下载](https://hudi.apache.org/releases/download/)、[1.2 适配与限制](https://hudi.apache.org/releases/release-1.2/)。
- **S14 Paimon**：[正式发行](https://github.com/apache/paimon/releases)、[2.1 运行时](https://paimon.apache.org/docs/2.1/project/download/)、[Trino 独立适配](https://paimon.apache.org/docs/2.1/ecosystem/trino/)。
- **S15 Polaris**：[1.8 发行](https://polaris.apache.org/downloads/1.8.0/)、[Trino](https://polaris.apache.org/guides/trino/)、[Spark 客户端边界](https://polaris.apache.org/releases/1.8.0/polaris-spark-client/)、[外部身份认证](https://polaris.apache.org/releases/1.8.0/managing-security/external-idp/)。
- **S16 Superset**：[6.1.0](https://github.com/apache/superset/releases/tag/6.1.0)、[Trino 集成](https://superset.apache.org/user-docs/databases/supported/trino/)。
- **S17 Hue**：[正式标签](https://github.com/cloudera/hue/releases)、[发布公告](https://gethue.com/categories/release/)。
- **S18 Metrics**：[独立源码仓库](https://github.com/apache/ambari-metrics)、[3.0.0 POM](https://raw.githubusercontent.com/apache/ambari-metrics/release-3.0.0/pom.xml)。不据 GitHub Releases 空列表推断 ASF 无其他发行。
- **S19 AWS SDK**：[官方版本](https://github.com/aws/aws-sdk-java-v2/releases)。组件最新版本不覆盖 Hadoop 配套约束。
- **S20 环境**：[openEuler 发行](https://www.openeuler.org/en/download/)、[Python 维护状态](https://devguide.python.org/versions/)。

- **S21 Hadoop 3.5 安全与运行时变更**：[3.5.0 概览](https://hadoop.apache.org/docs/r3.5.0/)。
- **S22 Hadoop 自身 CVE**：[官方公告及影响范围](https://hadoop.apache.org/cve_list.html)。
- **S23 Hadoop 3.5 配套依赖**：[正式 tag 的 POM](https://raw.githubusercontent.com/apache/hadoop/rel/release-3.5.0/hadoop-project/pom.xml)。
- **S24 Hadoop 升级边界**：[3.5.0 HDFS rolling upgrade](https://hadoop.apache.org/docs/r3.5.0/hadoop-project-dist/hadoop-hdfs/HdfsRollingUpgrade.html)。
