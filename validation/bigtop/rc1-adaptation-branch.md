# Bigtop RC1 Adaptation Branch Evidence

## 1. Metadata

```yaml
issue: 21
task: TASK-302
status: NOT_EXECUTED
evidence_type: branch_creation_template
result: UNKNOWN
```

## 2. Purpose

This file records the real Apache Bigtop RC1 adaptation branch creation evidence.

Do not mark this file as PASS without running `packaging/bigtop/create-rc1-adaptation-branch.sh` on the Build Lab host or an approved Bigtop checkout.

## 3. Expected Branch Identity

```yaml
base_project: apache/bigtop
base_version_or_ref: Bigtop 3.5.0
base_commit: UNKNOWN
branch_name: bigdata-1.0-rc1-openeuler22-rpm
working_tree_clean_before_patch: UNKNOWN
```

## 4. Required Command Output

### git rev-parse HEAD

```text
NOT_EXECUTED
```

### git branch --show-current

```text
NOT_EXECUTED
```

### git status --short

```text
NOT_EXECUTED
```

## 5. Scope Confirmation

```yaml
rc1_primary_os: openEuler22
package_type: rpm
package_manager: dnf
runtime: JDK8
allowed_change_scope: UNKNOWN
restricted_change_scope: UNKNOWN
rc1_patch_sequence_defined: PASS
```

## 6. Result Matrix

```yaml
bigtop_source_cloned: UNKNOWN
base_commit_recorded: UNKNOWN
branch_created: UNKNOWN
branch_name_verified: UNKNOWN
working_tree_clean_before_patch: UNKNOWN
adaptation_scope_confirmed: UNKNOWN
```

## 7. Decision

```yaml
result: UNKNOWN
next_action:
  - Run packaging/bigtop/create-rc1-adaptation-branch.sh on the Build Lab host.
  - Replace this template with real command output.
  - Keep Issue #21 open until all acceptance fields are PASS.
```
