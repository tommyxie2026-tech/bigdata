# Complete component dependency closure

This optional independent workflow compiles the full pinned PostgreSQL CDC
SQL connector reactor (`06581fc73b84b1da45fccf93441d96a118d9bfc1`, version 3.4.0),
using exactly the producer's module selection and `package` command. It verifies
both the real PostgreSQL table factory and bundled JDBC driver in the resulting
JAR. It does not substitute a probe project or claim an RPM release.

The source checkout and openEuler/JDK 11/Maven toolchain image are prepared once.
Each phase gets a clean copy of the source and a new output tree:

1. **Cold:** an empty client Maven repository. The client container has only the
   internal network, trusts the fixture TLS CA and mirrors all external Maven
   repositories through Reposilite. Only the proxy servers can reach upstream.
2. **Warm/server offline:** the proxy's egress networks are physically removed
   and checked, all three proxy servers restart, and the full component rebuilds
   using a second empty client repository. Matching dependency JAR/POM checksums
   are mandatory; neither the first client's cache nor reactor outputs are reused.
3. **Client offline:** a third clean source/output tree builds using Maven offline
   policy and the warm client's dependency repository in a `--network none`
   container. It must compile the same actual component again without networking.

Evidence records the immutable source SHA, single toolchain image ID, actual
compile durations, resulting JAR hashes and complete JAR/POM dependency checksum
inventories. JAR hashes are recorded rather than assumed reproducible because
upstream archives may include build timestamps. No new RPM is compiled or
published by this diagnostic.

A successful run establishes this component's Java build dependency closure for
this source/toolchain. It does not establish the closure of every big-data
component, actual production deployment, or npm/PyPI-heavy source builds. The
three registry fixtures have their own byte/egress/restart checks. The real
server/domain is still required before repository mirror activation.
