# Phase 1 交付设计与逐项验收

更新时间：2026-10-11。关联设计 Issue：#4、#5、#6、#7、#8、#9、#10、#11、#12。

本文是当前 openEuler/RPM 基线的设计补充，取代旧文档中的 Ubuntu/DEB、Bigtop 3.5.0 和旧候选版本部署指令。本文中的配置、测试和恢复步骤是待执行方案，不是已通过的集群测试记录。

## 1. 已交付基线与证据边界

| 项目 | 本次交付 |
|---|---|
| OS / 仓库 | openEuler 22.03 LTS SP4 / DNF RPM |
| 管理与打包 | Ambari 3.0.0 / Bigtop 3.6.0 |
| 数据服务 | Hadoop 3.4.3、ZooKeeper 3.8.4、Tez 0.10.5、Hive 4.0.1、Spark 3.5.8、HBase 2.6.5 |
| Java | 核心组件 CI 使用 JDK 8；Ambari 构建、安装测试使用 JDK 17；各服务独立 JAVA_HOME |
| 发行版本 | BIGDATA-1.0.0-RC1 |

[四组件 CI run 38070123732](https://github.com/tommyxie2026-tech/bigdata/actions/runs/38070123732) 中 Tez/Hive/Spark/HBase 的 12 个 Build/Test/Release job 实际 success。安装及版本冒烟证明包装可用，不证明七节点部署、故障切换或性能达标。repo 重入检查成功只证明已存在工件满足检查，不能新增一次运行时 PASS。

## 2. 3M3W1G 拓扑、资源与目录（#5）

主机名为示例，部署前必须写入真实 FQDN、IP、机架/可用区和磁盘清单。

| 主机 | 角色 | 验证环境初始资源 | 数据目录 |
|---|---|---|---|
| m1 | NN1、ZK1、JN1、HBase Master1 | 8 vCPU / 32 GiB | /data/nn、/data/jn、/data/zk |
| m2 | NN2、ZK2、JN2、HBase Master2 | 8 vCPU / 32 GiB | 同 m1 |
| m3 | ZK3、JN3、Ambari Server、元数据库 | 8 vCPU / 32 GiB | /data/zk、/data/jn、数据库独立卷 |
| w1 | DN、NM、RegionServer、RM1 | 16 vCPU / 64 GiB | /data/dn、/data/yarn、/data/hbase-local |
| w2 | DN、NM、RegionServer、RM2 | 16 vCPU / 64 GiB | 同 w1 |
| w3 | DN、NM、RegionServer | 16 vCPU / 64 GiB | 同 w1 |
| g1 | HMS、HS2、Spark History、客户端 | 8 vCPU / 32 GiB | /data/log、/data/tmp |

这是七节点功能验收布局：HMS/HS2 另各一实例放在 m3，便于验证单实例故障；数据库和 Ambari Server 仍是单点。生产需增加数据库 HA、管理节点和查询网关，隔离 RM 与 Worker 的资源争抢。两台 NN 规格相同；三个 ZK/JN 不落在同一故障域。Gateway 故障会中断其客户端会话，不等于 HDFS 故障。

初始磁盘建议：每 Master 系统盘 100 GiB，NN/JN/ZK 各独立 100 GiB SSD 卷；Worker 系统盘 100 GiB、DN 原始容量按业务测算，YARN 临时卷独立 SSD 至少 200 GiB；Gateway 临时卷 100 GiB。NN 容量必须以 inode 数量实测，不能按数据 TB 直接推算。HDFS 副本 3、目标使用率 70% 时，可用容量约为原始 DN 容量 × 0.7 / 3；还需扣除快照、临时数据和增长空间。Worker 内存预算先留 OS/Agent 8 GiB、RegionServer 16 GiB，再将余量作为 YARN 上限；这只是起始预算，需记录峰值 RSS/GC 后调优。

配置目录 /etc/<service>/conf；日志 /var/log/<service>；PID /run/<service>。实际 RPM 目录以 rpm -ql 为准，禁止盲目移动 RPM 管理文件。所有数据卷按 UUID 挂载并验证重启后挂载；不能把 DN/JN/数据库持久数据放在容器临时层。

### 网络和端口矩阵

| 服务 | 配置端口 | 允许来源 |
|---|---|---|
| Ambari UI / Agent | 8080 / 8440、8441 | 运维网 / Agent 主机；UI 经 TLS 入口 |
| SSH | 22 | 堡垒机及核准的初始化入口 |
| ZooKeeper | 2181 / 2888、3888 | 集群客户端 / 三个 ZK 节点互通 |
| NN RPC / UI | 8020 / 9870 | 集群和 Gateway / 运维网 |
| JN RPC / UI | 8485 / 8480 | NN 与 JN / 运维网 |
| DN transfer / IPC / UI | 9866 / 9867 / 9864 | 集群 / 集群 / 运维网 |
| RM client、scheduler、tracker、admin、UI | 8032、8030、8031、8033、8088 | 对应客户端、AM、NM、管理员、运维 |
| NM UI / shuffle | 8042 / 13562 | 运维网 / YARN 节点 |
| HMS / HS2 | 9083 / 10000 | 查询服务 / 授权 Gateway 客户端 |
| Spark History | 18080 | 运维与分析用户 |
| HBase Master RPC / UI | 16000 / 16010 | 集群 / 运维网 |
| RegionServer RPC / UI | 16020 / 16030 | 集群客户端 / 运维网 |
| PostgreSQL（本设计选用） | 5432 | Ambari、HMS 实例，拒绝全网开放 |
| RPM 镜像 TLS | 443 | 需安装软件包的主机 |

这些是本设计的配置值，交付时必须用生成配置和 ss -lntp 核对；Spark executor/driver 的动态端口需按受控节点网段放行或固定配置，不仅开放 History 端口。部署前验证正反向 DNS、NTP、跨节点 MTU 和防火墙规则。

## 3. Ambari Repository 与 Blueprint 设计（#4）

版本采用当前已经构建和发布的 Ambari 3.0.0，不把“最新版本”作为无验证升级依据。Ambari JDK 17 与大数据服务 JDK 8 分离，Agent 启动配置不得覆盖服务 JAVA_HOME。

仓库映射采用 https://<mirror>/repo/openeuler-22.03-lts-sp4/{common,hadoop,zookeeper,tez,hive,spark,hbase,ambari}/<version>/；common 按已发布目录版本配置，不能套用其他服务版本。每个仓库独立 repo-id，repodata 可达、RPM SHA256 校验通过后执行 dnf makecache。生产镜像启用 TLS 与仓库认证；当前 RC 的校验和不等于 RPM 签名，签名启用前不能宣称供应链签名完成。

Blueprint 主机组：m1、m2、m3 各 cardinality=1；w1、w2、w3 各=1；g1=1。角色严格采用第 2 节分布，避免通过 workers cardinality=3 随机分配 RM。需要 Stack 提供 ZOOKEEPER_SERVER、JOURNALNODE、ZKFC、HBASE_MASTER、HBASE_REGIONSERVER 和完整客户端组件定义；实际 component 名以部署 Stack 的 API 为准。

当前仓库 BIGDATA/1.0 只包含 HDFS/YARN/HIVE/SPARK metainfo 框架，single-node-hadoop.json 只是单节点样例，不能直接用于七节点 HA。七节点 Blueprint 是本设计的实施输入；未注册组件、缺失服务脚本和 Service Check 的实现及实测保留在 #14，不能把本文设计关闭解释为管理适配已完成。

部署顺序：上传适配 Stack → 重启并验证 Stack API → 注册 Blueprint → 用真实 hostname 的 host-group 映射提交集群 → 观察请求任务全成功 → 各服务 Service Check → 第 7 节数据冒烟 → HA 故障注入。任一组件不被 Stack 识别时停止安装，记录 API 响应和任务日志，不靠手工启动服务冒充 Ambari 安装通过。

## 4. HDFS / YARN / ZooKeeper 配置与切换（#6）

ZK 的 server.1/2/3 分别 m1/m2/m3:2888:3888，各节点 myid 唯一，clientPort=2181、dataDir=/data/zk，持久目录权限只给 zookeeper。先启动三节点，确认一 leader 两 follower，停一节点后客户端仍能读写；不得同时停两节点。

HDFS 配置清单（生成对应 XML property）：

| 属性 | 值 |
|---|---|
| fs.defaultFS | hdfs://bigdata |
| dfs.nameservices / dfs.ha.namenodes.bigdata | bigdata / nn1,nn2 |
| dfs.namenode.rpc-address.bigdata.nn1 / nn2 | m1:8020 / m2:8020 |
| dfs.namenode.http-address.bigdata.nn1 / nn2 | m1:9870 / m2:9870 |
| dfs.namenode.shared.edits.dir | qjournal://m1:8485;m2:8485;m3:8485/bigdata |
| dfs.client.failover.proxy.provider.bigdata | org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider |
| dfs.ha.automatic-failover.enabled | true |
| ha.zookeeper.quorum | m1:2181,m2:2181,m3:2181 |
| dfs.ha.fencing.methods | sshfence，使用隔离的 fencing 专用密钥 |
| dfs.namenode.name.dir / dfs.journalnode.edits.dir | file:///data/nn / /data/jn |
| dfs.datanode.data.dir / dfs.replication | file:///data/dn / 3 |

QJM 保证单个写入者；自动切换配置需要独立验证 fencing 能力。三 JN、两 NN+ZKFC；HA 不配置 SecondaryNameNode。首次初始化只在空集群执行，format NN、bootstrapStandby 和 formatZK 必须由受控安装流程一次性执行；恢复已有集群禁止 format。

YARN：yarn.resourcemanager.ha.enabled=true、ha.rm-ids=rm1,rm2、hostname.rm1=w1、hostname.rm2=w2、cluster-id=bigdata、zk-address=m1:2181,m2:2181,m3:2181、recovery.enabled=true、store.class=org.apache.hadoop.yarn.server.resourcemanager.recovery.ZKRMStateStore；NM 开启 mapreduce_shuffle，内存/CPU 以第 2 节预算配置。AM/NM/client 使用 HA 地址组，不写死单个 RM。

切换验收：记录两个 NN/RM 状态、启动持续 HDFS 读写和 YARN 作业；依次仅停当前 Active NN、恢复，再停当前 Active RM、恢复。记录故障时间、选主时间、客户端恢复时间、应用最终状态和数据 hash。验收目标暂设 RTO ≤120 秒、已确认 HDFS 写入不丢失、只有一个 Active；目标不是承诺，超时即 FAIL。每轮恢复正常冗余后才进行下一轮；禁止 --forceactive。

## 5. Hive / Spark 数仓设计（#7）

HMS 两实例 g1/m3 共享独立 PostgreSQL hive 数据库，hive.metastore.uris=thrift://g1:9083,thrift://m3:9083；数据库账号只授予 hive schema 权限。schematool 初始化/升级仅执行一次，所有 HMS 使用同一 schema 版本。数据库密码使用部署时密钥引用，不写入 Git。

HS2 两实例 g1/m3，hive.server2.support.dynamic.service.discovery=true、hive.server2.zookeeper.namespace=hiveserver2、hive.zookeeper.quorum=m1:2181,m2:2181,m3:2181。客户端通过 ZK service discovery 建立新会话；已运行查询不承诺透明续跑。hive.execution.engine=tez，tez.lib.uris 指向经核对的 HDFS Tez 库目录，库必须存在且应用账号可读。

Hive warehouse=/warehouse/tablespace/managed/hive，由 hive 拥有；临时目录按租户隔离。Spark 定位为 YARN 批处理与 Spark SQL，不启用 Standalone Master/Worker 作为第二调度体系。spark.eventLog.enabled=true、eventLog.dir=hdfs:///spark-history、history.fs.logDirectory=hdfs:///spark-history；History 先单实例，只影响历史展示不参与作业调度。Spark 客户端带经核对的 hive-site.xml，spark.sql.catalogImplementation=hive；验证外部表读写与 Metastore 可见性。

验收：HMS 停一实例后新客户端仍能访问元数据；HS2 停一实例后通过发现连接另一个实例并完成查询；Spark 作业 SUCCEEDED、结果正确、History 可查询应用。HMS DB 单点明确记录，不把两 HMS 误称完整元数据 HA。

## 6. HBase 部署、配置、恢复与 Java 边界（#8）

两 Master m1/m2，RegionServer w1/w2/w3。hbase.cluster.distributed=true、hbase.rootdir=hdfs://bigdata/hbase、hbase.zookeeper.quorum=m1,m2,m3、hbase.zookeeper.property.clientPort=2181、zookeeper.znode.parent=/hbase；配置 HDFS HA 客户端属性，禁止把 rootdir 指向某个 NN 的物理 hostname。WAL 使用 HDFS，/data/hbase-local 是本地临时目录而非持久表存储。

验收执行 create/put/get/scan/delete/disable/drop 测试专用表，保存行数和值。保持写入时只停止 Active Master，确认备用接管、RegionServer 不重复启动、读写在目标 120 秒内恢复；再单独停止一个 RS，确认 region 重新分配、WAL 恢复后测试值仍存在。每次恢复冗余后继续，不在故障中执行大范围 repair。

HBase 2.6.5 当前 CI JDK 8 安装与版本验证有证据；JDK 17 的反射、模块访问、Netty/native 与客户端依赖兼容性必须另行启动/负载/故障验证。不得为了绕过错误无审查地全局加入 --add-opens。#15 跟踪实际 Java 兼容验证，本文不宣称 JDK 17 集群支持。

## 7. Smoke Test、缺陷与验收模板（#11）

从 g1 使用授权账号执行，每次创建独立测试目录/表；记录命令、完整 stdout/stderr、exit code、时间与配置摘要。命令中的主机、路径、JAR 需从实际安装清单核实，不能把样例直接视为执行证据。

| ID | 执行动作 | PASS 条件 |
|---|---|---|
| SM01 | hdfs dfs -mkdir -p /acceptance/<run>; put 本地样本；cat 比较 sha256；fsck 此目录 | 原文一致、无 missing/corrupt block |
| SM02 | yarn jar <实际 mapreduce-examples.jar> pi 2 1000 | application FINISHED/SUCCEEDED、计算结果输出 |
| SM03 | beeline 通过 HS2 discovery 执行 create table、insert (1,'ok')、select count(*)、drop | 行数 1、值 ok、清理成功 |
| SM04 | spark-submit --master yarn --deploy-mode cluster --class org.apache.spark.examples.SparkPi <实际 spark-examples.jar> 2 | YARN SUCCEEDED、日志出现 Pi、History 有应用 |
| SM05 | hbase shell：create 'acceptance_<run>','cf'; put 一行；get/scan；disable/drop | get 值匹配、scan 行数 1、清理成功 |
| HA01–03 | 第 4、6 节分别停止 Active NN/RM/HBase Master | 冗余恢复、唯一 Active、数据正确、实测 RTO 合格 |

SM03 查询用专用测试数据库；初始化 warehouse 与 HDFS 账号目录在测试前由管理员完成。HS2 JDBC discovery URL：jdbc:hive2://m1:2181,m2:2181,m3:2181/;serviceDiscoveryMode=zooKeeper;zooKeeperNamespace=hiveserver2。不能用无 Kerberos 的测试账号检查结果推断生产多租户隔离。

缺陷记录必填：ID、关联 Issue、版本/commit/RPM hash、环境、复现步骤、预期/实际、日志链接、严重级别、影响面、修复 PR、回归用例、回退路径。Blocker 为无法部署/数据损坏/双 Active；Critical 为核心服务不可用或无恢复路径；不能仅降低严重度满足验收。

验收报告必填：执行人/时间、七主机清单、配置 commit、RPM SHA256、服务任务 ID、每个 SM/HA 的 PASS/FAIL/BLOCKED/NOT_EXECUTED、证据目录、RTO/RPO、遗留缺陷和签署人。仅全部必选测试 PASS 且 Blocker/Critical 清零后签署集群验收；设计文档完成或 RPM CI 通过不足以签署。

## 8. 安全基线与检查清单（#9）

| 账号 | 最小职责 | 目录权限与访问 |
|---|---|---|
| hdfs | HDFS 守护进程与受控管理 | NN/JN/DN 数据目录仅服务账号可写，0700 起始；跨服务访问通过 HDFS ACL |
| yarn / mapred | YARN/作业历史 | 私有 PID/log/local-dir，客户端不能写 daemon 目录 |
| zookeeper | ZK 服务 | /data/zk 0700，不给业务账号 shell |
| hbase | HBase 服务 | /hbase 专属 owner，配置/密钥不可由提交作业的账号修改 |
| hive / spark | 查询服务 / 历史服务 | warehouse/eventlog 按组授权，禁止全局 chmod 777 |
| ambari / 数据库账号 | 管理面 / 各自 schema | 密钥 0600、不同用途不同 DB 账号、不得共用管理员密码 |
| 运维个人账号 | 审计操作 | 堡垒机、命名账号、受控 sudo 白名单，禁止共享 root 凭据 |

RPM 实际用户/目录模式由 rpm -q 与 stat 核对；上述账号名是角色设计，若 RPM 共用 hdfs/JN 或 History 的账号必须登记映射，不能为满足表格改坏包装。Ambari Agent 若需要 root，则限定在受管主机，审计其动作；不是把 Agent 任意命令通道作为运维登录工具。

安装前检查：DNS/NTP；SSH 仅堡垒机；fencing 专用密钥最小权限；Ambari 默认密码首次登录即更换、个人账号分工；UI/TLS；repo 校验和；密钥不入 Git/日志；数据目录 owner/mode；DB 备份和恢复演练；监控异常登录。逐项保存命令输出与整改 Issue。

第一阶段 Kerberos 不默认启用，仅用于隔离的可信验证网络，不能承诺生产强身份隔离。后续启用步骤：准备 KDC 与 DNS/NTP → 规划各服务 principal/keytab 生命周期 → 演练 Ambari 服务身份映射 → HDFS/YARN/Hive/HBase/Spark 客户端逐项回归 → 关闭匿名入口 → 审计和密钥轮换 → 验证回退。生产准入需 Kerberos/等效身份认证和授权治理独立验收。

## 9. Runbook 清单（#10）

| 场景 | 执行顺序与停止条件 |
|---|---|
| 安装 | 仓库 checksum/DNF → JDK 隔离 → Agent 注册 → Stack/Blueprint 校验 → 数据库 schema → ZK/JN/NN/ZKFC → DN/YARN → HMS/HS2/Tez → Spark → HBase → SM/HA；任一步失败停止，不重复 format |
| 重启 | 保存状态/配置/当前任务 → 限制新任务 → 每次仅一个冗余实例 → 健康检查 → 下一实例；ZK/JN 必须保持多数，NN/RM 先 Standby 后受控切换 |
| HDFS 恢复 | 确認 Active 唯一、JN 多数和磁盘挂载 → 检查 NN/zkfc 日志 → 恢复故障 Standby → 验证 edits 追平与 fsck；双 Active/元数据不一致升级人工处理，不格式化 NN |
| HBase 恢复 | 先恢复 HDFS/ZK → 确认一个 Active Master → 观察 region 分配/WAL 恢复 → get/scan 校验 → 恢复失败 RS；卡住时保存 procedure 与日志，未经专门演练禁止修复工具批量改元数据 |
| 巡检 | 每日收集 NN/RM/RS/ZK 状态、DN 存活、missing block、队列/GC、磁盘≥70%趋势、时间同步、DB备份；健康异常先建缺陷再恢复，不把检查失败静默吞掉 |
| 扩容保留 | 新 Worker 规格/机架/Agent/版本一致 → 单节点加入 → DN/NM/RS 检查 → 受限 balancer 与 Region 迁移 → 容量/性能回归；回退前先 decommission，不直接删节点 |
| 升级保留 | 冻结版本与校验和 → 备份 schema/NN 元数据/配置 → 兼容性测试 → 测试集群演练 → 批次升级与回归；rollback 是否受 schema/data 格式限制必须先确定 |

详细执行模板见 ambari/runbooks/inspect-and-recover-hbase.md。当前 #14 的服务脚本尚未验收，安装 Runbook 不表示所有步骤可由当前 Stack 自动实现。

## 10. 设计 Review 与实施入口（#12）

已检查 architecture-decisions、platform-overview、roadmap、component-matrix、phase1-ha-design、bigtop-build-design、hbase-design、security-design、phase1-test-plan、phase1-acceptance-criteria：

| 冲突 / 缺口 | 处理 | 当前结果 |
|---|---|---|
| Ubuntu/DEB 与当前 openEuler/RPM 冲突 | 旧文档顶部标记历史内容，以本文和实际 ci 为当前部署设计 | 设计基线明确 |
| 旧版本与已发布版本混用 | 第 1 节唯一部署矩阵，旧升级计划关闭为 superseded | 不冒充旧版本通过 |
| 单节点 Blueprint 与七节点 HA 混淆 | 第 3 节标明缺失组件/服务脚本，#14 保留实施验收 | NOT_IMPLEMENTED |
| 包装冒烟被当成完整集群 PASS | 第 1、7 节明确证据层次，#16 保存真实七节点验收 | NOT_EXECUTED |
| JDK8/JDK17 进程边界模糊 | 各自 JAVA_HOME；#15 保存兼容性矩阵实测 | 未扩大支持声明 |
| 历史设计 Review 的工程状态过时 | 本次以当前 workflow 和发布为包装证据 | 包装完成，集群未验收 |

结论：#4–#11 的设计可以进入实施；#12 的本次设计审查完成。不能以此批准生产上线。按实施顺序处理 #20/#23 环境与工具链、#27 主机 ZK、#14 Ambari 适配、#15 Java 实测、#16 七节点 HA；#36 是独立 DeOS 集成，需要 GitHub App staging 权限。

## 参考

- [Hadoop 3.4.3 QJM HA](https://hadoop.apache.org/docs/r3.4.3/hadoop-project-dist/hadoop-hdfs/HDFSHighAvailabilityWithQJM.html)：NN/JN/ZKFC 和 fencing 配置核对。
- [Hadoop 3.4.3 RM HA](https://hadoop.apache.org/docs/r3.4.3/hadoop-yarn/hadoop-yarn-site/ResourceManagerHA.html)：RM 状态存储、选主和地址配置核对。
- [Ambari Blueprints](https://cwiki.apache.org/confluence/display/AMBARI/Blueprints)：host group、组件定义及集群请求设计。
- 实际包装清单、版本和契约以本仓库 ci/、scripts/ci/ 与已发布工件为准。
