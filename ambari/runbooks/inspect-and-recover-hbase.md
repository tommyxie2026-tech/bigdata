# 巡检与 HBase 恢复执行模板

本模板需在已安装并通过基本冒烟的授权测试集群执行；不声明当前七节点已通过。版本、角色和验收见 [Phase 1 交付设计](../../docs/phase1-delivery-design.md)。

## 记录和停止条件

每次建立带 UTC 时间的 evidence 目录；保存 hostname、rpm -qa、java -version、配置摘要（屏蔽密码/keytab）、操作者、变更单、命令退出码。仅操作一个故障域；HDFS/ZK 已不健康时停止 HBase 故障注入。

## 每日巡检

1. 从 Gateway 执行 hdfs haadmin -getServiceState nn1 与 nn2；应恰有一个 active。
2. 执行 hdfs dfsadmin -report，核对三 DN；执行 hdfs fsck /acceptance -files -blocks，缺失或损坏块为 FAIL。
3. 执行 yarn rmadmin -getServiceState rm1 / rm2，核对一个 active；yarn node -list 核对三 NM。
4. 三 ZK 主机使用实际服务管理命令检查状态；记录 leader/follower 和 ss -lntp 的 2181。未配置四字命令白名单时不使用 ruok 判断服务失败。
5. hbase shell 中执行 status 'detailed'，核对 Master、RS 数和 dead server；执行测试表 get/scan。
6. 采集 df -h、df -i、时间同步状态、服务日志错误、队列占用和 GC；数据卷未挂载、磁盘不足或多个 active 时立即停止变更。
7. 核对 PostgreSQL 备份时间、备份恢复测试结果；保存巡检报告和缺陷编号。

## HBase Master 故障恢复

1. 先确认 HDFS Active/Standby、JN/ZK 多数正常；保存 HBase 状态和 Master 日志。
2. 确认当前 Active Master 主机及实际 service unit（systemctl list-unit-files 或 Ambari API），不能猜单位名。
3. 在核准测试窗口仅停止当前 Active Master；记录停止时间，持续 get/put 测试专用表。
4. 观察备用 Master 接管，记录恢复时间、值和 region 状态；目标恢复时间 ≤120 秒，超过目标记录 FAIL。
5. 启动原 Master，确认其作为备用且仅一个 Active；再次 get/scan。
6. 失败时保存 procedure、WAL/RS/Master 日志，恢复原服务并联系管理员；不 format、不删 /hbase、不自动运行 HBCK 修复。

## RegionServer 故障恢复

1. 仅在冗余已恢复、HDFS/ZK 正常时停止一个 RS，保存该主机和 region 清单。
2. 确认 region 分配到其他 RS，核对测试表数据、WAL 恢复日志和错误。
3. 启动原 RS，核对三 RS 恢复、无持续 dead server/region-in-transition。
4. 若读写未恢复，暂停新增测试，保留证据；按缺陷处理，不反复重启所有服务。

## 报告

记录 PASS/FAIL/BLOCKED/NOT_EXECUTED、每个命令退出码、故障与恢复时间、数据校验、日志链接和缺陷 ID。未执行项保持 NOT_EXECUTED，不能因为命令模板存在而写 PASS。
