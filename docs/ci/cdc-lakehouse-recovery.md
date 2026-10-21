# CDC to Paimon recovery

The `CDC to Paimon recovery` workflow tests MySQL 8.0.36 and PostgreSQL 14.15 independently on clean openEuler containers, using published CDC 3.4.0, Flink 1.20.1 and Paimon 2.1.0 RPMs. It does not build or publish RPMs. Canonical connector build jobs must have actually succeeded in this repository; downloaded RPM bytes must match the published checksum. Engine and Paimon RPM checksums are checked on the runner.

The original connector fixture still supports its JDBC target. Setting `CDC_TARGET=paimon` installs the published Paimon Flink package and submits a real SQL insert from the CDC source into a Paimon primary-key table. Assertions run fresh, bounded batch readers of committed Paimon snapshots, compare every key/value and reject duplicates. They do not read the source database's target table.

Both fixtures check these exact states:

| Phase | Expected complete table |
| --- | --- |
| Initial snapshot | `(1, before), (2, delete-me)` |
| Insert/update/delete | `(1, after), (3, inserted)` |
| Restored after offline source changes | `(1, offline-update), (4, offline-insert)` |

The writer must complete a checkpoint, stop with a completed savepoint, and reach FINISHED before offline mutations. The restored job must have a new job ID and report the exact original savepoint path. Paimon reads observe checkpoint-committed lake files, consistent with the [Paimon batch-query contract](https://paimon.apache.org/docs/2.1/flink/sql-query/).

CI uploads separate evidence for each database, including exact-row logs, checkpoint/savepoint responses, Flink logs, source logs and package identity. A skipped job is not functional validation. This phase uses a local filesystem table shared by the writer and fresh readers; it does not yet prove HDFS/S3 persistence or Iceberg/Hudi recovery. Those remain separate acceptance steps.
