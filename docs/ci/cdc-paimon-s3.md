# CDC to Paimon on HTTPS S3

The independent `cdc-paimon-s3.yml` workflow extends the remote HDFS acceptance
profile with a separate, pinned SeaweedFS 4.48 S3 server. Both MySQL and PostgreSQL
reuse their published CDC RPMs, Flink 1.20.1 and Paimon 2.1.0. Hadoop 3.4.3 uses
the optional SDK 2.35.4 RPM from successful packaging run 39616625470, with exact
recipe, workflow provenance and checksum checks. This workflow does not rebuild
or publish any component RPM.

The object server owns its persistent data directory. The clean openEuler client
mounts only the public TLS certificate, published RPMs and test evidence. It uses
S3A over verified HTTPS with an explicit disposable credential provider and
bounded connection/retry settings. The fixture private key and object data are
not mounted into the client.

The existing recovery protocol checks exact snapshot rows, insert/update/delete,
a completed checkpoint, an actual stop/savepoint and source changes while the
job is stopped. The restored job must produce exactly `{1=offline-update,
4=offline-insert}`. After all Flink processes stop, the object server restarts
against the same data directory. A new Java 11 batch reader must retrieve the
same exact Paimon rows over HTTPS. The server's before/after start timestamps
must differ.

Evidence is uploaded separately for each source, including original build
identity, package/checksum checks, all row assertions, savepoint/checkpoint
records, TLS fixture provenance and the fresh reader's restart assertion.

Status: implementation candidate; real S3 lakehouse acceptance is pending CI.
The existing standalone S3 API and Hadoop S3A successes do not establish this
CDC/Paimon integration. Iceberg/Hudi target adapters and actual production proxy
deployment remain separate outstanding parts of the five-step delivery plan.
