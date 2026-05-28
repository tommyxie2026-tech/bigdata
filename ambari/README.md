# Ambari 工程目录

本目录用于沉淀基于 Apache Ambari 的 Hadoop 集群管理面工程资产。

## 目录结构

```text
ambari/
├── blueprints/
│   └── single-node-hadoop.json
├── configs/
│   ├── hdfs-site.json
│   ├── yarn-site.json
│   └── hive-site.json
├── scripts/
│   ├── ambari-env.sh
│   ├── create-cluster.sh
│   ├── service-check.sh
│   └── restart-stale-services.sh
└── runbooks/
    ├── install-cluster.md
    ├── restart-services.md
    └── recover-hdfs.md
```

## 使用方式

### 1. 配置 Ambari 连接信息

```bash
cd ambari/scripts
cp ambari-env.sh ambari-env.local.sh
```

根据实际环境设置：

```bash
export AMBARI_HOST="ambari.example.com"
export AMBARI_PORT="8080"
export AMBARI_USER="admin"
export AMBARI_PASSWORD="your-password"
export AMBARI_CLUSTER="bigdata-cluster"
```

### 2. 注册 Blueprint

```bash
./create-cluster.sh ../blueprints/single-node-hadoop.json
```

### 3. 执行服务检查

```bash
./service-check.sh HDFS
./service-check.sh YARN
./service-check.sh HIVE
```

### 4. 重启 stale 服务

```bash
./restart-stale-services.sh
```

## 说明

当前内容是第一版工程骨架，适合用于测试环境、方案验证和后续生产化改造。生产环境应进一步补充高可用、Kerberos、安全审计、容量规划和备份恢复策略。
