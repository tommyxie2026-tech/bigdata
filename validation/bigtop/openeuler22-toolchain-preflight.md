# openEuler22 Toolchain Preflight Evidence

## 1. Metadata

```yaml
task: TASK-304
patch: PATCH-002
status: NOT_EXECUTED
evidence_type: placeholder
result: UNKNOWN
```

## 2. Purpose

This file is the evidence target for the openEuler22 toolchain preflight.

It must be filled only after running the preflight script on the actual openEuler22 Build Lab host.

Do not mark this file as PASS without real command output.

## 3. Expected Environment

```yaml
os: openEuler22
package: rpm
manager: dnf
runtime: JDK8
bigtop_branch: bigdata-1.0-rc1-openeuler22-rpm
```

## 4. Command Output To Paste

### 4.1 OS

```text
TODO: paste output of cat /etc/os-release and uname -a
```

### 4.2 Package Manager

```text
TODO: paste output of dnf --version, rpm --version, rpmbuild --version
```

### 4.3 JDK

```text
TODO: paste output of java -version, javac -version, echo $JAVA_HOME
```

### 4.4 Build Tools

```text
TODO: paste output of git/curl/wget/tar/unzip/zip/make/gcc/g++/mvn/python3
```

### 4.5 Native Build Dependencies

```text
TODO: paste output of autoconf/automake/libtool/patch
```

### 4.6 Repository Tools

```text
TODO: paste output of createrepo_c --version or createrepo --version
```

### 4.7 Service Compatibility

```text
TODO: paste output of systemctl/chkconfig/service/alternatives/initscripts checks
```

## 5. Result Matrix

```yaml
os_identity: UNKNOWN
dnf: UNKNOWN
rpm: UNKNOWN
rpmbuild: UNKNOWN
jdk8_runtime: UNKNOWN
jdk8_compiler: UNKNOWN
java_home: UNKNOWN
git: UNKNOWN
curl: UNKNOWN
wget: UNKNOWN
tar: UNKNOWN
unzip: UNKNOWN
zip: UNKNOWN
make: UNKNOWN
gcc: UNKNOWN
gxx_or_cxx: UNKNOWN
maven: UNKNOWN
python3: UNKNOWN
autoconf: UNKNOWN
automake: UNKNOWN
libtool: UNKNOWN
patch: UNKNOWN
createrepo_or_createrepo_c: UNKNOWN
systemd: UNKNOWN
chkconfig: UNKNOWN
service: UNKNOWN
alternatives: UNKNOWN
initscripts: UNKNOWN
```

## 6. Missing Dependencies

```yaml
missing_dependencies: []
package_name_mismatches: []
```

## 7. Decision

```yaml
result: UNKNOWN
next_action:
  - Run PATCH-002 preflight script on openEuler22 Build Lab.
  - Replace TODO sections with real command output.
  - Update result matrix.
```
