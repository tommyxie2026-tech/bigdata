# openEuler22 Toolchain Install Log

## 1. Metadata

```yaml
issue: 20
task: TASK-301
status: NOT_EXECUTED
evidence_type: install_log_template
result: UNKNOWN
```

## 2. Purpose

This file records the actual package installation evidence for the openEuler22 Build Lab.

Do not mark this file as PASS without real command output from the Build Lab host.

## 3. Target Environment

```yaml
os: openEuler22
package: rpm
manager: dnf
runtime: JDK8
workspace: /opt/bigdata-rc1
```

## 4. Install Command

```bash
dnf install -y \
  git \
  curl \
  wget \
  tar \
  unzip \
  zip \
  which \
  make \
  gcc \
  gcc-c++ \
  autoconf \
  automake \
  libtool \
  patch \
  rpm-build \
  rpmdevtools \
  createrepo_c \
  java-1.8.0-openjdk-devel \
  maven \
  python3 \
  python3-pip \
  systemd \
  chkconfig \
  initscripts
```

## 5. Command Output

```text
NOT_EXECUTED
```

## 6. Result Matrix

```yaml
base_dependencies_installed: UNKNOWN
jdk8_runtime_available: UNKNOWN
jdk8_compiler_available: UNKNOWN
dnf_available: UNKNOWN
rpm_available: UNKNOWN
rpmbuild_available: UNKNOWN
createrepo_c_available: UNKNOWN
workspace_created: UNKNOWN
network_or_mirror_access_verified: UNKNOWN
```

## 7. Decision

```yaml
result: UNKNOWN
next_action:
  - Run the install command on the openEuler22 Build Lab host.
  - Paste the real command output in this file.
  - Run infra/build-lab/openeuler22-build-lab-preflight.sh.
```
