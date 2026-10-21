# Component dependency downloads and build recovery

The existing component lifecycle first verifies a published RPM's version,
source/compatibility identity, checksum and clean installation. A valid repository
continues to bypass compilation. The standalone Hadoop and ZooKeeper workflows
now use that same check. `force_build=true` on a manual dispatch explicitly opts
into rebuilding. Version-matrix documentation changes no longer start these two
standalone compilers.

## Persistent dependency downloads

All three build entrypoints use the same restore/save composite actions. Cache
scope includes openEuler, runner OS/architecture, component/version, JDK, source
identity, build recipes and Maven mirror identity. Each changed inventory gets a
new immutable run/attempt snapshot; restore chooses the latest matching snapshot.
Unchanged inventories are not uploaded again. Save also runs after compilation
failure, retaining successful downloads. Maven `.lastUpdated` failure markers and
Gradle locks are removed after the container exits.

Only `.m2/repository`, `.gradle/caches` and `.gradle/wrapper` are cached. Maven
settings, credentials, daemon state, RPMs and test/release evidence are excluded.
A dependency cache hit never means the RPM or its functional tests passed.
Existing output checksums and release gates remain authoritative. Cache scope is
not a substitute for pinning upstream source identities and dependency versions.

## Network policy

The common Maven/Gradle command wrapper supports these environment variables:

| Variable | Default | Meaning |
| --- | --- | --- |
| `MAVEN_MIRROR_URL` | unset | HTTPS Maven repository manager; `external:*` routes external Maven repositories through it |
| `MAVEN_NETWORK_MODE` | `online` | `offline` writes Maven offline settings and passes `--offline` to Gradle; missing cached inputs fail without online fallback |
| `MAVEN_RETRY_ATTEMPTS` | `3` | Maximum command invocations, including the first |
| `MAVEN_RETRY_ATTEMPT_SECONDS` | `7200` | Per-command deadline |
| `MAVEN_RETRY_TOTAL_SECONDS` | `10800` | Overall command/retry/backoff budget |
| `MAVEN_RETRY_DELAY_SECONDS` | `15` | Backoff between eligible transfer failures |
| `DEPENDENCY_PREPARE_SECONDS` | `600` | Entire Hadoop dependency warmup deadline |

The workflows forward repository variables `MAVEN_MIRROR_URL` and
`MAVEN_NETWORK_MODE` into the build container. Leave the mirror unset until a real
repository manager is available and validated. Authenticated mirrors can use the
Maven server ID `ci-dependency-mirror`; settings credentials must be provisioned
separately and are never put into the dependency cache. This change does not
provision an internal repository server or redirect npm/PyPI/Gradle repositories.

Maven has bounded read/connect options. Only recognized transient artifact or
metadata transfers (connection reset, timeout, HTTP 429/502/503/504) are eligible
for retry. Compiler errors, missing artifacts, offline misses and command
deadlines fail immediately. Timeout cleanup terminates the command's process
group. Attempts retain the same build workspace and have separate logs, while a
new wrapper invocation replaces its aggregate log so old failures cannot be
mistaken for current evidence. Build steps end before the job deadline to leave
time for cache and evidence upload.

## Dependency preparation and offline rollout

Hadoop and the Hive/Spark/HBase Bigtop paths warm the explicitly identified Maven
dependencies before compilation. Each warmup command has shorter limits (90s per
attempt, 180s total, three attempts), under the 600s preparation budget. This
moves known transfer failures earlier and preserves downloads for subsequent runs.

This list is **not** a complete dependency closure. Bigtop builds invoke nested
Maven projects/profiles and also fetch source archives/toolchains. Do not enable
repository-wide offline mode until the exact component build has warmed and
validated every required dependency. Maven offline settings alone do not disable
Git, DNF, curl or other network clients. Offline mode does not automatically build
all components without network access.

The `Dependency Policy` workflow provides a small live openEuler proof. It
prepares a pinned Maven fixture online, removes build outputs, disables the
container's network, rebuilds offline, and compares bytecode checksums. It also
requires a cold offline build to fail without retries. A second job saves and
restores a dependency snapshot and checks that settings did not enter the cache.
These checks validate the mechanism without recompiling unchanged component RPMs.

For full component offline readiness, first warm the exact source/profile/toolchain
in the relevant container, then run that component with both offline resolution
and container networking disabled. Record that component's success before using
an offline default. Continue to reuse the existing RPM for ordinary regression
and release work while validating readiness separately.
