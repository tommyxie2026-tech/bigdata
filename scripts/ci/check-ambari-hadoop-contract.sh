#!/usr/bin/env bash
set -euo pipefail

WORK_ROOT="${WORK_ROOT:-/tmp/ambari-hadoop-contract}"
AMBARI_REF="${AMBARI_REF:-release-3.0.0}"
BIGTOP_REF="${BIGTOP_REF:-branch-3.6}"

rm -rf "${WORK_ROOT}"
mkdir -p "${WORK_ROOT}"

AMBARI_RAW="https://raw.githubusercontent.com/apache/ambari/${AMBARI_REF}"
BIGTOP_RAW="https://raw.githubusercontent.com/apache/bigtop/${BIGTOP_REF}"

curl -fsSL "${AMBARI_RAW}/ambari-server/src/main/resources/stacks/BIGTOP/3.3.0/metainfo.xml" -o "${WORK_ROOT}/ambari-stack-metainfo.xml"
curl -fsSL "${AMBARI_RAW}/ambari-server/src/main/resources/stacks/BIGTOP/3.3.0/services/HDFS/metainfo.xml" -o "${WORK_ROOT}/ambari-hdfs-33.xml"
curl -fsSL "${AMBARI_RAW}/ambari-server/src/main/resources/stacks/BIGTOP/3.2.0/services/HDFS/metainfo.xml" -o "${WORK_ROOT}/ambari-hdfs-32.xml"
curl -fsSL "${AMBARI_RAW}/ambari-server/src/main/resources/stacks/BIGTOP/3.2.0/properties/stack_packages.json" -o "${WORK_ROOT}/stack_packages.json"
curl -fsSL "${BIGTOP_RAW}/bigtop.bom" -o "${WORK_ROOT}/bigtop.bom"
curl -fsSL "${BIGTOP_RAW}/bigtop-packages/src/rpm/hadoop/SPECS/hadoop.spec" -o "${WORK_ROOT}/hadoop.spec"

grep -q "<extends>3.2.0</extends>" "${WORK_ROOT}/ambari-stack-metainfo.xml"
grep -q "<version>3.3.6-1</version>" "${WORK_ROOT}/ambari-hdfs-33.xml"
grep -q "openeuler22" "${WORK_ROOT}/ambari-hdfs-32.xml"
grep -Fq 'hadoop_${stack_version}' "${WORK_ROOT}/ambari-hdfs-32.xml"
grep -q '"hadoop-client"' "${WORK_ROOT}/stack_packages.json"
grep -q '"hadoop-hdfs-namenode"' "${WORK_ROOT}/stack_packages.json"
grep -q '"hadoop-hdfs-datanode"' "${WORK_ROOT}/stack_packages.json"
grep -q '"hadoop-yarn-resourcemanager"' "${WORK_ROOT}/stack_packages.json"
grep -q '"hadoop-yarn-nodemanager"' "${WORK_ROOT}/stack_packages.json"
grep -A16 "'hadoop'" "${WORK_ROOT}/bigtop.bom" | grep -q "3.4.3"
grep -Fq "%define hadoop_pkg_name hadoop%{pkg_name_suffix}" "${WORK_ROOT}/hadoop.spec"

cat > "${WORK_ROOT}/contract-report.md" <<'EOF'
# Ambari 3.0.0 <-> Bigtop 3.6.0 Hadoop Contract Report

status: ADAPTATION_REQUIRED

Verified compatible contract surfaces:
- Ambari BIGTOP stack explicitly supports openeuler22.
- Ambari uses versioned Hadoop RPM naming via stack_version.
- Ambari package catalog expects Hadoop client, HDFS, YARN and MapReduce package families.
- Bigtop Hadoop RPM spec uses pkg_name_suffix and is structurally compatible with versioned package naming.

Confirmed drift:
- Ambari 3.0.0 active BIGTOP stack is 3.3.0, extending 3.2.0.
- Ambari BIGTOP 3.3.0 HDFS metadata declares Hadoop 3.3.6-1.
- BIGDATA target is Bigtop 3.6.0 / Hadoop 3.4.3.

Required adaptation before full RC:
1. Add or generate a BIGTOP 3.6 stack/overlay for Ambari 3.0.0.
2. Resolve stack_version to the Bigtop 3.6 RPM package suffix.
3. Revalidate HDFS, YARN and MAPREDUCE2 service versions.
4. Re-run package, path, lifecycle and Service Check contracts against tested RPMs.

Current classification: not yet production-compatible; adaptation required.
EOF

cat "${WORK_ROOT}/contract-report.md"