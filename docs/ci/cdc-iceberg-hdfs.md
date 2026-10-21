# CDC to Iceberg with Java 17 and remote HDFS

The independent `cdc-iceberg-hdfs.yml` candidate workflow reuses published
Iceberg 1.12.0, Flink 1.20.1, Hadoop 3.4.3 and both CDC 3.4.0 RPMs. Original
source/compatibility identities and RPM checksums are required. No component
RPM is rebuilt.

Iceberg uses the published Java 17 runtime. The test drivers select Java 17
only for this target, preserving Java 11 for JDBC, Paimon and Hudi. Module
exports/opens come from Apache Flink release-1.20.1's config.yaml and apply to
both the real Flink services and fresh batch assertion JVMs. Maven dependencies
have a separate Java 17 cache namespace.

The real Iceberg Hadoop catalog stores format-v2 primary-key tables on a
separate HDFS service. Upsert mode must consume CDC insert/update/delete
changelog events. Exact complete row maps, completed checkpoints and actual
savepoint stop/restoration remain mandatory. After HDFS restarts without
formatting, a fresh Java 17 reader must return exactly
`{1=offline-update,4=offline-insert}`.

The earlier published RPM profile's Flink classpath check does not establish
this CDC functionality. This integration remains unverified until both source
jobs actually pass. Storage paths are never mounted into the client, and
no publication or general cross-target success is inferred from local checks.
