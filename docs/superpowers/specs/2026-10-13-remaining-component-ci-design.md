# Remaining Query and Lakehouse Component CI Design

## Status

Draft for user review. Scope follows the user's approval to continue with Hue, Iceberg, Hudi, and Paimon after Kafka/Flink. No implementation, component version pin, repository promotion, or product release is approved by this draft alone.

## Goal

Extend the existing idempotent RPM lifecycle to the remaining approved query and lakehouse components without rebuilding already-current packages or weakening evidence requirements.

## Current baseline

- Kafka 3.4.1 and Flink 1.20.1 RPM lifecycles are merged and promoted.
- The catalog and reusable lifecycle currently cover ZooKeeper, Hadoop, Tez, Hive, Spark, HBase, Kafka, and Flink.
- The lifecycle can fast-pass only after exact package/version, manifest/checksum, repository metadata, and clean install validation; a successful fast path intentionally skips Build/Test/Release.
- Apache Bigtop 3.6 packaging metadata contains Kafka and Flink, but no Hue, Iceberg, Hudi, or Paimon packaging definitions ([pinned Bigtop 3.6 BOM](https://github.com/apache/bigtop/blob/branch-3.6/bigtop.bom), [package-source tree](https://github.com/apache/bigtop/tree/branch-3.6/bigtop-packages/src/common)). Treat additions as custom packages rather than pretending they are native Bigtop builds.

## Proposed scope and batches

### Batch 1: Hue feasibility and Iceberg

1. **Hue feasibility gate:** confirm a maintained upstream release, source integrity, supported Python/runtime dependencies on openEuler 22.03 LTS SP4, and an RPM packaging path. If feasible, package Hue as a service RPM, install it in a clean image, start it with disposable metadata storage, check its HTTP health/UI endpoint, and verify a configured HiveServer2 or Trino connection. If not feasible, report the concrete blocker and stop Hue packaging without claiming success.
2. **Iceberg:** model it as an integration artifact, not a daemon. Pin Iceberg and each engine connector against the repository's Spark 3.5.8 and Flink 1.20.1 baseline. Build an allow-listed JAR/runtime RPM set and run actual table create/write/read checks in supported engines. Advertise only engine/catalog combinations that pass; begin with the compatibility matrix approved in implementation review.

### Batch 2: Hudi and Paimon

- Add each as a separate optional integration profile after Batch 1 package and lifecycle contracts are stable.
- Independently pin source, connector coordinates, engine compatibility, and catalog/storage assumptions.
- Run real write/read smoke tests before promotion. A successful compile or package install alone is insufficient evidence.

## Shared lifecycle and idempotency

- Reuse the existing repository check → Build → clean Test → Release Candidate → stage gate and exact-current repository fast path.
- Fast-pass only when every configured runtime RPM/JAR, version, source identity, compatibility tuple, checksum, manifest, and repository metadata match, and a clean openEuler install/load check succeeds.
- Missing, stale, corrupt, incomplete, or incompatible artifacts take the normal lifecycle or fail closed.
- Build and Test provenance must identify the same source and run; Release Candidate accepts only successful Test evidence for those exact artifacts.
- Use component-scoped dispatch and dependency edges so work on one profile does not trigger unrelated component builds. Reuse valid, same-tree test evidence when the established lifecycle permits it.
- Keep each component/profile in its own PR and promote only through the existing RPM repository PR flow.

## Version and source policy

- Do not use floating `latest` tags or moving branches.
- Select maintained stable releases only after checking primary upstream release and compatibility documentation.
- Record immutable source URL plus archive SHA-256 or commit SHA, exact RPM/JAR allow-list, runtime/JDK/Python, engine versions, catalog, and test profile in the component configuration and compatibility matrix.
- If openEuler 22.03 cannot meet a component's runtime requirements, stop before long builds and present the specific supported alternatives for review; do not change the existing components' global toolchain.

## Test contracts

- **Hue service profile:** clean install, daemon startup, health/UI endpoint, disposable metadata backend, and one real configured query-service connection.
- **Lakehouse integration profile:** clean RPM installation, expected connector JAR loading by the selected engine, table creation, write/read verification, and manifest evidence for each supported compatibility tuple.
- All tests run against the artifacts produced by the current Build run unless an exact-current fast path has validated repository artifacts and their prior test provenance.
- Failed or cancelled stages block promotion; skipped stages count as success only when the repository fast path has explicit passing evidence.

## Non-goals

- Rebuilding or republishing Kafka/Flink or the existing Hadoop ecosystem when their exact-current fast path passes.
- Multi-node production certification, HA, throughput benchmarking, or cluster deployment in component package smoke jobs.
- Publishing an aggregate repository tarball or public product release as part of component CI work.
- Treating lakehouse table formats as standalone daemons.

## Acceptance criteria

1. Hue feasibility is recorded with upstream/runtime evidence before implementation; an infeasible route is reported without a false green pipeline.
2. Component configuration rejects missing versions, floating refs, incomplete artifact allow-lists, and invalid dependency edges.
3. Hue's service package is promotable only after clean install, startup, health, and endpoint-connection tests pass.
4. Iceberg, Hudi, and Paimon artifacts are promotable only for explicitly pinned engine/catalog combinations whose table write/read tests pass.
5. A complete, checksum-valid, installable and provenance-valid unchanged repository set takes the fast path and avoids Build/Test/Release; incomplete or corrupted state does not.
6. Component dispatch runs only the selected component and declared prerequisites/descendants; unrelated components remain on verified fast paths.
7. Promotion PRs contain only declared runtime artifacts plus checksums, a provenance manifest, and valid repository metadata.
8. Existing component behavior and prior successful artifact evidence remain unchanged.

## Risks and open questions for implementation review

- Hue Python dependencies may not be reproducibly buildable on the current openEuler image; resolve this with the feasibility gate before committing to a builder.
- Iceberg/Hudi/Paimon connector compatibility is tuple-specific and can change across engine, Scala, JDK, catalog, and storage versions.
- Some connector JARs may require upstream licenses/notices and dependency bundling decisions before RPM promotion.
- Container smoke jobs validate package and local integration basics, not production cluster readiness.
