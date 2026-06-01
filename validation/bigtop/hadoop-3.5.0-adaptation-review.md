# TASK-202R Hadoop 3.5.0 Bigtop Adaptation Review

## 1. Metadata

```yaml
task: TASK-202R
name: Hadoop 3.5.0 Bigtop Adaptation Review
owner: Agent-B
sprint: Sprint-1
status: completed-initial-review
result: CONDITIONAL_GO
confidence: medium
```

## 2. Objective

验证 BIGDATA-1.0 RC1 坚持 Hadoop 3.5.0 目标版本时，Bigtop 3.5.0 需要做哪些适配工作。

本任务不再讨论是否将 Hadoop 降级到 Bigtop 当前 BOM 版本，而是评估如何把 Bigtop 适配到项目要求版本。

## 3. Required Version

```yaml
required:
  hadoop: 3.5.0
  bigtop: 3.5.0
  os: openEuler22
  jdk: JDK8
```

## 4. Current Evidence

### 4.1 Hadoop 3.5.0 Exists In Apache Download Directory

Apache Hadoop download directory contains `hadoop-3.5.0/`.

The Hadoop 3.5.0 directory contains:

- `hadoop-3.5.0-src.tar.gz`
- `hadoop-3.5.0.tar.gz`
- `hadoop-3.5.0-aarch64.tar.gz`
- `RELEASENOTES.md`
- `CHANGELOG.md`
- `.asc` signature files
- `.sha512` checksum files

Evidence:

- https://downloads.apache.org/hadoop/common/
- https://downloads.apache.org/hadoop/common/hadoop-3.5.0/

### 4.2 Current Bigtop BOM Does Not Yet Match Required Hadoop Version

Current observed Bigtop BOM shows Hadoop as `3.4.3`.

Observed current BOM evidence:

```yaml
bigtop_current_visible_bom:
  hadoop: 3.4.3
```

Required BIGDATA RC1 version:

```yaml
required:
  hadoop: 3.5.0
```

### 4.3 Hadoop DEB Packaging Path Exists

Bigtop has Hadoop DEB packaging metadata under:

```text
bigtop-packages/src/deb/hadoop/control
```

This proves a Hadoop DEB packaging path exists, but does not prove it works unchanged for Hadoop 3.5.0.

## 5. Required Adaptation Points

### 5.1 BOM Version Update

Required change:

```groovy
version { base = '3.5.0'; pkg = base; release = 1 }
```

Current observed line uses `3.4.3`.

### 5.2 Source Tarball Path

Expected source tarball for Bigtop source build:

```text
hadoop-3.5.0-src.tar.gz
```

Expected Apache path:

```text
/hadoop/common/hadoop-3.5.0/
```

### 5.3 Patch Compatibility

Need to check Bigtop Hadoop patch set against Hadoop 3.5.0.

Validation steps:

```text
1. Apply existing Bigtop Hadoop patches to Hadoop 3.5.0 source.
2. Record patch failures.
3. Classify each patch as:
   - still needed
   - obsolete
   - needs refresh
   - blocked
```

### 5.4 DEB Packaging Compatibility

Need to validate packages generated from Hadoop 3.5.0 still satisfy Bigtop package layout.

Critical packages:

- hadoop
- hadoop-hdfs
- hadoop-yarn
- hadoop-mapreduce
- hadoop-client
- hadoop-conf-pseudo
- hadoop-yarn-resourcemanager
- hadoop-yarn-nodemanager
- hadoop-hdfs-namenode
- hadoop-hdfs-datanode

### 5.5 JDK8 Build Compatibility

Bigtop stack JDK defaults to JDK8 via `BIGTOP_JDK` default behavior.

But Hadoop 3.5.0 with JDK8 must be proven by real build.

Validation command target:

```bash
BIGTOP_JDK=8 ./gradlew hadoop-pkg
```

The exact command may need adjustment based on Bigtop build workflow.

### 5.6 openEuler22 Build Environment

Because Sprint-1 primary OS is adjusted to openEuler22, the Hadoop 3.5.0 build should be tested against openEuler22 toolchain.

Validation targets:

- openEuler22 build container or VM
- JDK8
- Maven
- protobuf/toolchain dependencies
- RPM/DEB decision check

Note: openEuler is RPM-oriented. If RC1 requires DEB, that becomes a packaging model conflict. This must be resolved in Sprint-1.

## 6. Key Risk: OS / Package Format Mismatch

### R-B202R-001: openEuler22 And DEB Packaging May Conflict

Severity: Critical

Earlier RC1 planning assumed DEB / apt repository. openEuler22 is RPM-oriented, while Bigtop Hadoop DEB path exists separately.

This creates a new architecture decision point:

```yaml
option_a:
  os: Ubuntu22
  package: deb/apt

option_b:
  os: openEuler22
  package: rpm/yum-or-dnf
```

Current evidence favors openEuler22 for Ambari BIGTOP stack alignment, but DEB/apt was the previous packaging target.

This must be resolved before RC1 packaging freeze.

### R-B202R-002: Hadoop 3.5.0 Patch Drift

Severity: High

Existing Bigtop Hadoop packaging and patches may need refresh for Hadoop 3.5.0.

### R-B202R-003: Hadoop 3.5.0 Runtime Compatibility Unknown

Severity: High

Even if package build succeeds, HDFS/YARN service layout and Ambari service definitions still require runtime verification.

## 7. Recommendation

```yaml
result: CONDITIONAL_GO
required_hadoop: 3.5.0
strategy: adapt_bigtop_to_required_version
blockers:
  - package_format_decision_required
  - real_build_required
next_action:
  - decide RC1 package format for openEuler22: RPM vs DEB
  - create Bigtop adaptation branch/patchset
  - update Hadoop BOM version to 3.5.0
  - run source download and checksum verification
  - run Hadoop package build
  - archive build logs under validation/bigtop/
```

## 8. Exit Criteria For Real Validation

TASK-202R can only become PASS when all of the following are true:

```yaml
hadoop_3_5_0_source_download: PASS
checksum_verification: PASS
patch_apply: PASS
package_build: PASS
package_install: PASS
hdfs_smoke_test: PASS
yarn_smoke_test: PASS
```

## 9. Decision

Hadoop 3.5.0 remains the required RC1 target.

Bigtop current BOM gap is accepted as adaptation work.

The next critical decision is no longer Hadoop version selection. It is:

```text
openEuler22 + RPM
vs
Ubuntu22 + DEB
```

This decision must be resolved before M2 Packaging Ready.
