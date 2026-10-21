# CDC to Hudi on remote HDFS

The independent `cdc-hudi-hdfs.yml` workflow reuses published Hudi 1.2.1,
Flink 1.20.1, Hadoop 3.4.3 and MySQL/PostgreSQL CDC 3.4.0 RPMs. It never compiles
new component RPMs. The same two database recovery protocols used for Paimon
must prove exact snapshot/IUD rows, a completed checkpoint, actual savepoint
stop, changes while stopped and exact rows after restoration.

The new test-only target dispatcher preserves Paimon and JDBC paths. Hudi uses
a real COPY_ON_WRITE upsert table with database commit ordering, not synthetic
JDBC materialization. The primary key is the Hudi record key. Fresh bounded
batch readers assert complete row maps and reject duplicate keys.

HDFS runs in a separate openEuler container from verified published RPMs. The
client never mounts storage files. After recovery, the storage service restarts
without formatting, and a fresh Java process must read exactly
`{1=offline-update,4=offline-insert}`. Evidence retains source/compatibility
identities, package digests and service before/after timestamps.

Status: runtime acceptance pending CI. Local contracts and review do not prove
Hudi CDC changelog compatibility. Iceberg uses a separate published JDK 17
runtime and remains an outstanding adapter in the five-step plan.
