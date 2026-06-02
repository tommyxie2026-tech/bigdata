# TASK-305 ZooKeeper 3.9.5 RPM Build Runbook

## 1. Metadata

```yaml
task: TASK-305
name: ZooKeeper 3.9.5 RPM Build Evidence
phase: M2-Prep
status: draft-ready
owner: Agent-B
component: zookeeper
version: 3.9.5
```

## 2. Objective

在 `openEuler22 + RPM + DNF + JDK8` 构建实验室中，执行 ZooKeeper 3.9.5 的首次真实 RPM 构建，并归档构建证据。

该任务是从“适配评审”进入“真实构建验证”的第一个组件级任务。

## 3. Preconditions

开始前必须满足：

```yaml
openEuler22_build_lab: READY
PATCH_001_rc1_bom_version: APPLIED
PATCH_002_openeuler22_toolchain_preflight: PASS
bigtop_adaptation_branch: READY
branch_name: bigdata-1.0-rc1-openeuler22-rpm
runtime: JDK8
```

禁止在缺失 toolchain preflight 证据的情况下启动构建。

## 4. Required Evidence Files

本任务必须产出：

```text
validation/bigtop/zookeeper-3.9.5-rpm-build-log.md
validation/bigtop/zookeeper-3.9.5-rpm-package-list.txt
validation/bigtop/zookeeper-3.9.5-dnf-install.md
validation/ha/zookeeper-quorum.md
```

如构建失败，必须产出：

```text
validation/bigtop/zookeeper-3.9.5-rpm-build-failure.md
```

## 5. Environment Setup

```bash
export BIGDATA_RC1_HOME=/opt/bigdata-rc1
export BIGTOP_JDK=8
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
export PATH=$JAVA_HOME/bin:$PATH

cd $BIGDATA_RC1_HOME/src/bigtop

git branch --show-current
git rev-parse HEAD
git status
```

Record the output into:

```text
validation/bigtop/zookeeper-3.9.5-rpm-build-log.md
```

## 6. Verify BOM Target

Before build, confirm BOM contains ZooKeeper 3.9.5:

```bash
grep -n "zookeeper" bigtop.bom -A 20 -B 5
```

Expected:

```yaml
zookeeper: 3.9.5
```

If BOM still points to another version, stop and classify as:

```yaml
failure_class: bom_patch_not_applied
```

## 7. Source Download And Checksum

Run the Bigtop source preparation step used by the project build flow.

Candidate command:

```bash
./gradlew zookeeper-download
```

If the target name differs, record the actual successful command.

Evidence to record:

```yaml
source_download: PASS | FAIL
source_file:
checksum_or_signature: PASS | FAIL | NOT_AVAILABLE
```

## 8. RPM Build Command

Candidate command:

```bash
BIGTOP_JDK=8 ./gradlew zookeeper-rpm
```

If the actual Gradle target differs, record the actual command in the log.

All output must be captured:

```bash
BIGTOP_JDK=8 ./gradlew zookeeper-rpm 2>&1 | tee validation/bigtop/zookeeper-3.9.5-rpm-build-log.md
```

If the build workspace cannot write directly into repository evidence path, copy the log after build.

## 9. Package List Collection

After successful build, collect RPM list:

```bash
find . -name "*.rpm" | sort | tee validation/bigtop/zookeeper-3.9.5-rpm-package-list.txt
```

Expected package classes:

```text
zookeeper
zookeeper-server
zookeeper-rest
zookeeper-native
```

RC1 blocking package:

```text
zookeeper-server
```

`zookeeper-rest` and `zookeeper-native` are non-blocking unless required by downstream tests.

## 10. Local DNF Repository Validation

Create a local repository from generated RPMs:

```bash
mkdir -p $BIGDATA_RC1_HOME/repo/zookeeper-3.9.5
find . -name "*.rpm" -exec cp {} $BIGDATA_RC1_HOME/repo/zookeeper-3.9.5/ \;
createrepo_c $BIGDATA_RC1_HOME/repo/zookeeper-3.9.5
```

Create temporary repo file:

```bash
cat >/etc/yum.repos.d/bigdata-rc1-zookeeper.repo <<EOF
[bigdata-rc1-zookeeper]
name=BIGDATA RC1 ZooKeeper
baseurl=file://$BIGDATA_RC1_HOME/repo/zookeeper-3.9.5
enabled=1
gpgcheck=0
EOF
```

Validate:

```bash
dnf clean all
dnf makecache
dnf search zookeeper
dnf install -y zookeeper zookeeper-server
```

Archive output to:

```text
validation/bigtop/zookeeper-3.9.5-dnf-install.md
```

## 11. Runtime Smoke Test

Minimum single-node smoke test:

```bash
systemctl daemon-reload
systemctl enable zookeeper-server || true
systemctl start zookeeper-server
systemctl status zookeeper-server --no-pager
```

ZooKeeper CLI test:

```bash
zkCli.sh -server 127.0.0.1:2181 <<EOF
ls /
quit
EOF
```

Archive output to:

```text
validation/ha/zookeeper-quorum.md
```

For RC1, single-node startup is sufficient for TASK-305. Multi-node quorum validation remains part of HA validation.

## 12. Failure Classification

If build fails, classify the first blocking failure:

```yaml
failure_class:
  - bom_patch_not_applied
  - source_download_failed
  - checksum_failed
  - patch_apply_failed
  - missing_build_dependency
  - rpm_spec_failure
  - file_list_failure
  - openEuler_package_name_mismatch
  - jdk8_build_failure
  - unknown
```

Failure report template:

```markdown
# ZooKeeper 3.9.5 RPM Build Failure

## Summary

result: FAIL
failure_class:
first_failed_command:

## Environment

os:
jdk:
branch:
commit:

## Error Excerpt

```text
paste first relevant error here
```

## Next Action

- [ ] dependency fix
- [ ] spec patch
- [ ] patch refresh
- [ ] source URL/checksum fix
```

## 13. Exit Criteria

TASK-305 is PASS only when:

```yaml
bom_target_verified: PASS
source_download: PASS
checksum_or_signature: PASS
rpm_build: PASS
rpm_package_list: PASS
dnf_repo_metadata: PASS
dnf_install: PASS
zookeeper_server_start: PASS
zkcli_connection: PASS
evidence_archived: PASS
```

If any item fails, TASK-305 remains FAIL or BLOCKED, not PARTIAL PASS.

## 14. Decision

ZooKeeper 3.9.5 is the first component build target because it is a prerequisite for:

- HDFS HA
- YARN HA
- HBase
- Ambari-managed cluster validation

This runbook is the canonical execution guide for the first real RPM build in M2-Prep.
