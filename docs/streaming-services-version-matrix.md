# Trino 483 CI input lock

This file records the upstream and runtime inputs used by the Trino custom RPM
adapter. It is a CI input lock, not a claim that a release has already passed
the clean-container test or been promoted into the RPM repository.

| Input | Locked value | Evidence |
|---|---|---|
| Trino version | 483 | Pinned \`trino-packages\` POM and README |
| RPM source | \`trinodb/trino-packages\` | [pinned source commit](https://github.com/trinodb/trino-packages/tree/5533573115277b8c452348f28dcf011aea14dd71) |
| Runtime archive | Temurin JDK 25.0.4+7, Linux x64 | [Adoptium binary endpoint](https://api.adoptium.net/v3/binary/version/jdk-25.0.4%2B7/linux/x64/jdk/hotspot/normal/eclipse) |
| Runtime SHA256 | \`e58fcdcd637b25c03ca84cbbcefc70d11efb8f4b4cbd05decc9f661769d77f94\` | Checked by \`install-pinned-java-runtime.sh\` before extraction |
| OS | openEuler 22.03 LTS SP4 | Shared CI container |
| Runtime RPM allowlist | \`trino-server-rpm\` | POM emits \`trino-server-rpm-483.noarch.rpm\` |

The upstream package project documents that it builds the RPM from the Trino
server tarball, requires Java 25, and installs Java separately from the RPM.
Its documented build is \`./mvnw clean install\`; the CI build runs the pinned
Maven wrapper and delegates service behavior to a clean-container test.
See the [upstream RPM packaging README](https://github.com/trinodb/trino-packages/blob/5533573115277b8c452348f28dcf011aea14dd71/trino-server-rpm/README.md).

The custom builder skips its Docker-based upstream integration-test profile
because the RPM build container does not nest Docker. The separate lifecycle
Test stage installs the built RPM into a fresh openEuler container, starts
Trino as its service account, checks \`/v1/info\`, and executes \`SELECT 1\` through
the statement API. Release Candidate promotion is gated on that evidence.

Revalidate the source commit, archive checksum, Java version, runtime package
name, and clean-container test whenever this version is updated.
