# openEuler22 Package Name Mapping

## 1. Metadata

```yaml
issue: 20
task: TASK-301
status: NOT_EXECUTED
evidence_type: package_name_mapping_template
result: UNKNOWN
```

## 2. Purpose

This file records package-name differences between the initial Build Lab dependency list and the selected openEuler22 minor release.

Only record mappings after running the DNF install or query commands on the real Build Lab host.

## 3. Mapping Table

| Required capability | Initial package name | openEuler22 package name | Status | Evidence |
|---|---|---|---|---|
| Git client | `git` | `git` | UNKNOWN | Not executed |
| Curl client | `curl` | `curl` | UNKNOWN | Not executed |
| Wget client | `wget` | `wget` | UNKNOWN | Not executed |
| Archive tools | `tar`, `unzip`, `zip` | `tar`, `unzip`, `zip` | UNKNOWN | Not executed |
| Compiler toolchain | `gcc`, `gcc-c++`, `make` | `gcc`, `gcc-c++`, `make` | UNKNOWN | Not executed |
| Autotools | `autoconf`, `automake`, `libtool`, `patch` | `autoconf`, `automake`, `libtool`, `patch` | UNKNOWN | Not executed |
| RPM build toolchain | `rpm-build`, `rpmdevtools` | `rpm-build`, `rpmdevtools` | UNKNOWN | Not executed |
| RPM repository metadata | `createrepo_c` | `createrepo_c` | UNKNOWN | Not executed |
| JDK8 compiler/runtime | `java-1.8.0-openjdk-devel` | `java-1.8.0-openjdk-devel` | UNKNOWN | Not executed |
| Maven | `maven` | `maven` | UNKNOWN | Not executed |
| Python runtime | `python3`, `python3-pip` | `python3`, `python3-pip` | UNKNOWN | Not executed |
| Service compatibility | `systemd`, `chkconfig`, `initscripts` | `systemd`, `chkconfig`, `initscripts` | UNKNOWN | Not executed |

## 4. Query Commands

```bash
dnf info <package>
dnf provides <binary-or-file>
rpm -q <package>
command -v <binary>
```

## 5. Decision

```yaml
result: UNKNOWN
next_action:
  - Run the install command on the real Build Lab host.
  - Replace UNKNOWN values with PASS, FAIL, or RENAMED.
  - If a package name differs, record the real package and DNF evidence.
```
