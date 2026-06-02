# ZooKeeper 3.9.5 RPM Build Log

## 1. Metadata

```yaml
task: TASK-305
component: zookeeper
version: 3.9.5
status: NOT_EXECUTED
evidence_type: placeholder
result: UNKNOWN
```

## 2. Purpose

This file is the build log evidence target for ZooKeeper 3.9.5 RPM build.

It must be filled only after running the real build on the openEuler22 Build Lab.

Do not mark this file as PASS without real build output.

## 3. Preconditions

```yaml
openEuler22_toolchain_preflight: UNKNOWN
PATCH_001_rc1_bom_version: UNKNOWN
PATCH_002_openeuler22_toolchain_preflight: UNKNOWN
bigtop_adaptation_branch: UNKNOWN
jdk8: UNKNOWN
```

## 4. Build Environment

```yaml
os: TODO
kernel: TODO
branch: TODO
commit: TODO
java_version: TODO
javac_version: TODO
BIGTOP_JDK: TODO
JAVA_HOME: TODO
```

## 5. BOM Verification

Expected:

```yaml
zookeeper: 3.9.5
```

Actual command output:

```text
TODO: paste grep output from bigtop.bom
```

## 6. Source Download

Command:

```bash
TODO: paste actual source download command
```

Output:

```text
TODO
```

Result:

```yaml
source_download: UNKNOWN
checksum_or_signature: UNKNOWN
```

## 7. RPM Build

Command:

```bash
BIGTOP_JDK=8 ./gradlew zookeeper-rpm
```

Actual command used:

```bash
TODO
```

Build output:

```text
TODO: paste full or relevant build log output
```

Result:

```yaml
rpm_build: UNKNOWN
```

## 8. Failure Classification

If failed, classify:

```yaml
failure_class: UNKNOWN
first_failed_command: TODO
first_relevant_error: TODO
```

Allowed failure classes:

```yaml
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

## 9. Package List

If build succeeds, package list must be copied to:

```text
validation/bigtop/zookeeper-3.9.5-rpm-package-list.txt
```

## 10. Decision

```yaml
result: UNKNOWN
next_action:
  - Run TASK-305 on openEuler22 Build Lab.
  - Replace TODO sections with real build output.
  - Create package list and DNF install evidence if build succeeds.
  - Create failure report if build fails.
```
