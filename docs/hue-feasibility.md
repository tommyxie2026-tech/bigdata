# Hue Packaging Feasibility

Assessment date: 2026-10-15  
Target: openEuler 22.03 LTS SP4, x86_64, service RPM and the repository's existing component lifecycle.

## Decision

**The source snapshot and Python/native build-prerequisite layer are feasible; Hue remains non-promotable pending frontend, source-build, packaging, and runtime gates.** The official upstream release line is stale for a new deployment: GitHub currently lists 4.11.0, published 2023-01-19. Upstream development remains active; the candidate source commit is `65d9e489f400ac151029b33c5a2bd9df31e167da` (2026-10-09). This is a reproducible development snapshot, not a claim that a new stable upstream release exists. The package must record both the version reported by Hue and this immutable source commit.

The target-image DNF preflight now passes on the exact image digest recorded below. That proves the listed Python/native toolchain packages resolve and install; it does **not** prove Hue's Python requirements, frontend toolchain, application build, RPM, service startup, or backend query. Do not promote Hue until each of those gates passes.

## Evidence

| Area | Evidence and implication |
| --- | --- |
| Upstream source | [Official Hue repository](https://github.com/cloudera/hue) has recent commits; the candidate source identity is the full commit SHA above. Do not build from a moving branch or use a floating release alias. |
| Formal release | [Official releases](https://github.com/cloudera/hue/releases) list 4.11.0 as the latest formal release (2023-01-19). A pinned post-release commit is required for current fixes and must be identified as a snapshot. |
| Python | [Hue development guide](https://github.com/cloudera/hue/blob/master/docs/docs-site/content/developer/development/_index.md) documents Python 3.8/3.9 and Django 3.2; a 2026 upstream commit explicitly drops Python 3.8. Use Python 3.9 only. The target-image preflight installed Python 3.9.9 and `python3-devel` successfully. |
| Frontend | The upstream development guide requires Node.js 20 or later to build Vue assets. Use an explicitly pinned, checksum-verified Node.js 22 build tool if the image repositories do not provide a suitable version. Node.js is build-time only and must not become an RPM runtime dependency. |
| Native build dependencies | [Hue installation dependencies](https://docs.gethue.com/administrator/installation/dependencies/) lists the compiler, Python headers, Kerberos/SASL, OpenSSL, XML/XSLT, SQLite, LDAP, and GMP development libraries. DNF successfully installed `gcc`, `gcc-c++`, `gmp-devel`, `krb5-devel`, `libffi-devel`, `libxml2-devel`, `libxslt-devel`, `openldap-devel`, `openssl-devel`, `sqlite-devel`, and `cyrus-sasl-devel` in the target image. This is package-resolution evidence only, not a Hue build. |
| Target image | GitHub Actions run [38636939284](https://github.com/tommyxie2026-tech/bigdata/actions/runs/38636939284) passed the dependency preflight on `openeuler/openeuler:22.03-lts-sp4`, resolved digest `sha256:f4f7b49430a7eec2f8dfd9d25d6d677cb81aa7ccbf2cd4cac70c4f9acc39f7ee`; it verified Python `3.9.9`. The workflow did not download Hue source or compile it. |
| Build and install route | Upstream documents `make apps` and installation using a prefix. A custom service RPM can own an isolated `/opt/hue` application tree, a dedicated service user, systemd unit, and configuration under `/etc/hue`; the RPM must contain only the installed runtime tree, service files, and upstream license/notice. Do not package a database server. |
| Metadata and backend | Production Hue requires a persistent transactional metadata database; MySQL/MariaDB or PostgreSQL are documented options. The clean test should use a disposable PostgreSQL instance and temporary data, then configure a real HiveServer2 endpoint and execute a bounded query through Hue. Health/UI alone is not sufficient. |
| Bigtop | Bigtop 3.6 has no Hue BOM/package recipe. Hue must use the repository's custom adapter rather than be represented as a native Bigtop build. |

## Candidate package and lifecycle contract

- Component: `hue`; builder: `custom`; artifact: `service-rpm`.
- Source: `https://github.com/cloudera/hue.git`, pinned to `65d9e489f400ac151029b33c5a2bd9df31e167da`.
- Candidate RPM allowlist: `bigdata-hue-server` only. No bundled database, JDK, Node.js, or unrelated Hue development files.
- Build runtime: Python 3.9; Node.js 22 is build-only; Java is optional unless a separately selected JDBC proxy is included.
- Clean test: install only the candidate Hue RPM and declared prerequisites; provision temporary metadata storage; start the packaged service; verify HTTP readiness; connect to the configured HiveServer2 and run a small query; collect logs and provenance; tear down the temporary database and service on both success and failure.
- The component remains unpromotable until the Node/frontend toolchain, pinned-source build/install layout, exact RPM allowlist, checksum/provenance checks, clean installation, service startup, and real backend query all pass on the current PR head.

## Remaining feasibility and implementation gates

1. Confirm a pinned/checksummed Node.js 22 toolchain and reproducible frontend build path compatible with the target image.
2. Verify the upstream `make apps` and `make install PREFIX=...` output layout and runtime entrypoint at the pinned source SHA, including Python requirement installation.
3. Confirm the Hue HiveServer2 client can execute a query against the test backend using the chosen Python/runtime and temporary metadata database.

If any gate fails, mark Hue blocked with the failing dependency or interface. Do not create a successful-looking artifact, skip a required stage, or promote an RPM on partial evidence.
