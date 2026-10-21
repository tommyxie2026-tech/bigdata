# CDC → Paimon on remote HDFS

The published MySQL/PostgreSQL connector RPMs, Flink 1.20.1, Paimon 2.1.0 and
Hadoop 3.4.3 are reused with their canonical build identity and SHA-256 checks.
This workflow contains no RPM compilation or publication.

A dedicated storage container runs a real standalone HDFS NameNode/DataNode.
The clean openEuler Flink client container has no mount of the storage data.
It uses `hdfs://127.0.0.1:9000/warehouse/<connector>-<run>` through the shared
fixture network namespace. This is network HDFS, not a local filesystem alias.
A separate URI validator rejects unsupported schemes, credentials, queries,
fragments, traversal and SQL delimiters before catalog construction. Its Java
positive/negative tests run on CI without downloading a JDK locally.

Both connectors retain the original exact snapshot and I/U/D assertions,
completed checkpoint evidence, stopped savepoint, changes while stopped and
restored exact final rows. Each assertion launches a fresh bounded reader.
After that protocol succeeds, HDFS itself restarts without reformatting its
persistent namespace. Changed process start timestamps are required, and a new
client JVM must still read the exact final Paimon rows. Evidence includes the
warehouse URI, HDFS reports/logs and both start timestamps.

Actual HDFS CI must pass before claiming this profile succeeds. The previously
successful local warehouse run 39637652324 is the baseline only; it cannot stand
in for remote storage. S3A-backed Paimon and the later Iceberg/Hudi expansion
remain separate requirements of the five-step delivery plan.
