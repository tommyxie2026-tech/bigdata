# Bigdata

BIGDATA provides an openEuler RPM distribution and delivery foundation for the Hadoop ecosystem, with a roadmap toward an open lakehouse and governed AI data platform.

## Quick deployment

This quick start targets the current **BIGDATA-1.0.0-RC1** package baseline on
**openEuler 22.03 LTS SP4**. It is for a lab or single-node evaluation; it is not
a production HA procedure or evidence that the seven-node cluster has passed
acceptance testing. The tested component versions and important limitations
are listed in [Phase 1 delivery and acceptance](docs/phase1-delivery-design.md).

### 1. Prepare the host and RPM repositories

Use an openEuler 22.03 LTS SP4 host with DNS and time synchronization configured.
For a single-node lab, allocate at least 8 vCPU, 32 GiB RAM, and persistent
storage appropriate for the data you will test. Do not put test data on a
temporary filesystem.

Publish or mirror the project RPM repositories over HTTPS, then create a DNF
repository file on the host. Replace `<mirror>` with the URL of your published
repository. Bigtop package repositories include the `bigtop-3.6` directory;
the common dependency repository is versioned independently at `3.6.0`.

```ini
# /etc/yum.repos.d/bigdata.repo
[bigdata-common]
name=Bigdata common dependencies
baseurl=https://<mirror>/repo/openeuler-22.03-lts-sp4/bigtop-3.6/common/3.6.0/
enabled=1
gpgcheck=0

[bigdata-hadoop]
name=Bigdata Hadoop 3.4.3
baseurl=https://<mirror>/repo/openeuler-22.03-lts-sp4/bigtop-3.6/hadoop/3.4.3/
enabled=1
gpgcheck=0

[bigdata-zookeeper]
name=Bigdata ZooKeeper 3.8.4
baseurl=https://<mirror>/repo/openeuler-22.03-lts-sp4/bigtop-3.6/zookeeper/3.8.4/
enabled=1
gpgcheck=0

[bigdata-ambari]
name=Bigdata Ambari 3.0.0
baseurl=https://<mirror>/repo/openeuler-22.03-lts-sp4/ambari/3.0.0/
enabled=1
gpgcheck=0
```

Add corresponding `bigtop-3.6` repository stanzas for `tez/0.10.5`,
`hive/4.0.1`, `spark/3.5.8`, and `hbase/2.6.5` when those services are needed.
For production,
serve signed packages, configure repository authentication, and set `gpgcheck=1`
with the trusted signing key; the current RC checksums alone are not RPM
signatures. Refresh metadata and confirm the repositories are reachable:

```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf repolist
```

### 2. Install and start Ambari

Install the Ambari packages and JDK 17 from the approved repositories. Keep the
service runtime Java selection separate: the current Hadoop ecosystem RPMs use
the JDK 8 baseline, while Ambari uses JDK 17.

```bash
sudo dnf install ambari-server ambari-agent java-17-openjdk
sudo ambari-server setup
sudo systemctl enable --now ambari-server
```

On every managed host, install and configure the agent to point to the Ambari
Server, then start it:

```bash
sudo dnf install ambari-agent java-17-openjdk
# Set the Ambari Server hostname in /etc/ambari-agent/conf/ambari-agent.ini
sudo systemctl enable --now ambari-agent
```

Open `http://<ambari-server>:8080`, replace the initial credentials, and register
the host. Restrict the UI to the management network and put it behind TLS for
shared environments.

### 3. Try a single-node cluster

The repository includes a single-host Blueprint example and helper scripts:

```bash
cd ambari/scripts
# Export these for this shell; do not commit the password.
export AMBARI_HOST="<ambari-server>"
export AMBARI_USER="admin"
read -rsp "Ambari password: " AMBARI_PASSWORD; echo
export AMBARI_PASSWORD
export AMBARI_CLUSTER="bigdata-lab"
./create-cluster.sh ../blueprints/single-node-hadoop.json
```

The first command registers the Blueprint. To submit its cluster request, create
a host mapping file using the exact hostname registered in Ambari:

```json
{
  "blueprint": "single-node-hadoop",
  "host_groups": [
    { "name": "master", "hosts": [{ "fqdn": "<registered-hostname>" }] }
  ]
}
```

Save this as `host-mapping.json` and submit it with:

```bash
./create-cluster.sh ../blueprints/single-node-hadoop.json host-mapping.json
```

The Blueprint is a **limited example**, not a complete deployable definition
for every shipped RPM. BIGDATA/1.0 currently has partial HDFS/YARN/Hive/Spark
Stack metadata; ZooKeeper, Tez, HBase, HA roles, and all service lifecycle/check
scripts are not yet fully integrated and validated in Ambari. Therefore, use
the Blueprint to inspect the workflow or for controlled experimentation only;
do not treat its submission as a successful end-to-end installation. Follow the
[cluster installation runbook](ambari/runbooks/install-cluster.md) and stop
when Ambari does not recognize a service or its components.

### 4. Install packages directly for package-level evaluation

If you only need to verify package availability on a lab host, install the
required packages with DNF (for example):

```bash
sudo dnf install zookeeper-server hadoop hadoop-client
```

Add `hive`, `tez`, `spark`, or `hbase` packages only when their matching
repositories are enabled. Package installation and version checks are not a
cluster deployment test. Use the service-specific steps in the
[installation runbook](ambari/runbooks/install-cluster.md) before starting
daemons; never run initialization or format commands against an existing data
directory.

### Production deployment

For a production-like topology, use the [Phase 1 delivery design](docs/phase1-delivery-design.md)
for the 3 Master + 3 Worker + 1 Gateway layout, resource sizing, storage,
network ports, service ordering, smoke tests, and recovery procedures. The
single-node Blueprint is not a substitute for that topology or its HA
acceptance checks.

## 快速部署（中文）

本指南对应当前 **BIGDATA-1.0.0-RC1**，目标系统为 **openEuler 22.03 LTS SP4**，适用于实验或单机体验。它不是生产高可用部署流程，也不代表七节点集群已经通过验收。组件版本与已知限制见[第一阶段交付与验收说明](docs/phase1-delivery-design.md)。

### 1. 准备主机和 RPM 仓库

准备一台 openEuler 22.03 LTS SP4 主机，并配置好 DNS 和时间同步。单机实验建议至少 8 vCPU、32 GiB 内存，并为测试数据准备持久化存储；不要把数据放在临时文件系统中。

通过 HTTPS 发布或镜像项目 RPM 仓库，然后在主机上创建 DNF 仓库配置。将 `<mirror>` 替换为实际仓库地址。Bigtop 组件仓库路径包含 `bigtop-3.6`；公共依赖仓库当前版本为 `3.6.0`，与组件版本分别管理。

```ini
# /etc/yum.repos.d/bigdata.repo
[bigdata-common]
name=Bigdata common dependencies
baseurl=https://<mirror>/repo/openeuler-22.03-lts-sp4/bigtop-3.6/common/3.6.0/
enabled=1
gpgcheck=0

[bigdata-hadoop]
name=Bigdata Hadoop 3.4.3
baseurl=https://<mirror>/repo/openeuler-22.03-lts-sp4/bigtop-3.6/hadoop/3.4.3/
enabled=1
gpgcheck=0

[bigdata-zookeeper]
name=Bigdata ZooKeeper 3.8.4
baseurl=https://<mirror>/repo/openeuler-22.03-lts-sp4/bigtop-3.6/zookeeper/3.8.4/
enabled=1
gpgcheck=0

[bigdata-ambari]
name=Bigdata Ambari 3.0.0
baseurl=https://<mirror>/repo/openeuler-22.03-lts-sp4/ambari/3.0.0/
enabled=1
gpgcheck=0
```

需要相应服务时，再添加 `bigtop-3.6` 下的 `tez/0.10.5`、`hive/4.0.1`、`spark/3.5.8` 和 `hbase/2.6.5` 仓库。生产环境应使用签名包、仓库认证，并配置可信签名密钥后设置 `gpgcheck=1`；RC 校验和不等同于 RPM 签名。刷新并检查仓库：

```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf repolist
```

### 2. 安装并启动 Ambari

从已批准的仓库安装 Ambari 和 JDK 17。注意区分 Java 运行时：当前 Hadoop 生态组件以 JDK 8 为基线，Ambari 使用 JDK 17。

```bash
sudo dnf install ambari-server ambari-agent java-17-openjdk
sudo ambari-server setup
sudo systemctl enable --now ambari-server
```

在每台受管主机上安装 Agent，将 Agent 指向 Ambari Server 后启动：

```bash
sudo dnf install ambari-agent java-17-openjdk
# 在 /etc/ambari-agent/conf/ambari-agent.ini 中配置 Ambari Server 主机名
sudo systemctl enable --now ambari-agent
```

访问 `http://<ambari-server>:8080`，首次登录后更换初始凭据并注册主机。共享环境应限制管理网访问，并在入口配置 TLS。

### 3. 体验单节点 Blueprint

仓库提供单节点 Blueprint 示例和辅助脚本：

```bash
cd ambari/scripts
# 在当前 Shell 中设置以下环境变量；不要把密码提交到 Git。
export AMBARI_HOST="<ambari-server>"
export AMBARI_USER="admin"
read -rsp "Ambari password: " AMBARI_PASSWORD; echo
export AMBARI_PASSWORD
export AMBARI_CLUSTER="bigdata-lab"
./create-cluster.sh ../blueprints/single-node-hadoop.json
```

上面的命令会先向 Ambari 注册 Blueprint。若要提交建群请求，还需创建主机映射文件，并使用 Ambari 中登记的准确主机名：

```json
{
  "blueprint": "single-node-hadoop",
  "host_groups": [
    { "name": "master", "hosts": [{ "fqdn": "<registered-hostname>" }] }
  ]
}
```

将其保存为 `host-mapping.json`，再提交请求：

```bash
./create-cluster.sh ../blueprints/single-node-hadoop.json host-mapping.json
```

该 Blueprint 是**有限示例**，并非覆盖全部 RPM 的完整部署定义。当前 BIGDATA/1.0 的 Stack 元数据仅部分覆盖 HDFS/YARN/Hive/Spark；ZooKeeper、Tez、HBase、高可用角色以及全部服务生命周期和检查脚本尚未在 Ambari 中完整集成并验证。因此请仅用于查看部署流程或受控实验，不要把提交 Blueprint 当作端到端安装成功。请参照[集群安装 Runbook](ambari/runbooks/install-cluster.md)；如果 Ambari 无法识别服务或组件，应停止部署并排查。

### 4. 直接安装 RPM 进行包级体验

若只想在实验主机上确认包可用，可用 DNF 安装所需包，例如：

```bash
sudo dnf install zookeeper-server hadoop hadoop-client
```

仅在启用了对应仓库后再安装 `hive`、`tez`、`spark` 或 `hbase`。包安装和版本检查不等于集群部署测试。启动守护进程前，请按[安装 Runbook](ambari/runbooks/install-cluster.md) 执行对应配置步骤；不要对已有数据目录重复执行初始化或格式化操作。

### 生产部署

生产化拓扑、资源规格、存储、网络端口、服务启动顺序、冒烟测试和恢复流程，请参照[第一阶段交付设计](docs/phase1-delivery-design.md)中的 3 Master + 3 Worker + 1 Gateway 方案。单节点 Blueprint 不能替代该拓扑或其 HA 验收。

## Documentation

* [Next-generation Data & AI Platform Roadmap](docs/next-generation-platform-roadmap.md) - Current baseline, release milestones, AI use cases, acceptance gates, 90-day backlog, and resource planning (updated 2026-10-11).
* [Technical Design](docs/technical-design.md) - Big data architecture, module design, repository planning, and engineering conventions.
* [Phase 1 Delivery and Acceptance](docs/phase1-delivery-design.md) - Current RC1 versions, deployment design, resources, checks, and known gaps.
* [Ambari Cluster Installation Runbook](ambari/runbooks/install-cluster.md) - Installation and operational checklist.

## References

* [Apache Bigtop](apache-bigtop/) - Packaging, testing, and deployment resources for the Apache Hadoop ecosystem.
