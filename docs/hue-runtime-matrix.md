# Hue Runtime Matrix

Status: candidate contract; not yet a tested runtime or release claim.

| Dimension | Pin / decision | Evidence |
| --- | --- | --- |
| Hue version | 4.11.0 | Upstream `VERSION` at pinned source reports `4.11.0`. |
| Source | `https://github.com/cloudera/hue.git` at `65d9e489f400ac151029b33c5a2bd9df31e167da` | Immutable Git commit; this is a post-release source snapshot. |
| Target | openEuler 22.03 LTS SP4, x86_64 | Native/Python DNF preflight completed; full source build remains pending. |
| Python | 3.9 | Upstream development guide documents 3.8/3.9; selected pinned source drops Python 3.8. |
| Frontend build | Node.js 22.23.0, x86_64 tar.xz, SHA-256 `14d7de44f235534799f8b171a4050d9a6a4bc99c87e053a25d3d54afa580aa20` | Official Node.js release checksum listing; build-only, excluded from RPM runtime. |
| Java | None in Hue runtime | CI currently records JDK 17 as a common toolchain field; this does not add Java to the Hue RPM requirements. |
| Package | `bigdata-hue-server` | Exact candidate RPM allowlist; package contains Hue application runtime, service/config files, and license notices only. |
| Query backend | Trino 483 | Candidate clean-test backend; actual Hue connection and bounded SQL query must pass before promotable status. |
| Metadata | Disposable PostgreSQL | Must be ephemeral and removed on success or failure; no database server is bundled. |

The source commit reports release version 4.11.0, while upstream's last formal release is older. The package and repository manifest must retain the full source commit so this snapshot is not confused with a rebuilt upstream release tag.
