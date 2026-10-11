# Bigdata

This repository collects references and notes for big data ecosystem projects.

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

## Documentation

* [Technical Design](docs/technical-design.md) - Big data architecture, module design, repository planning, and engineering conventions.
* [Phase 1 Delivery and Acceptance](docs/phase1-delivery-design.md) - Current RC1 versions, deployment design, resources, checks, and known gaps.
* [Ambari Cluster Installation Runbook](ambari/runbooks/install-cluster.md) - Installation and operational checklist.

## References

* [Apache Bigtop](apache-bigtop/) - Packaging, testing, and deployment resources for the Apache Hadoop ecosystem.
