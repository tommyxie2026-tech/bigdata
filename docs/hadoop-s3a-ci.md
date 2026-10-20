# Hadoop S3A integration profile

This test-only profile consumes the published Hadoop 3.4.3 and Hadoop client/HDFS/MapReduce/YARN RPMs,
plus Bigtop utils/Groovy/jsvc common packages, at immutable repository commit
`865074386ad88dd82ea9fd043e385e7b1cfe0ca9`. Each RPM is checked against that
commit's SHA256SUMS on the CI runner. No RPM is compiled or repackaged, and no
release/promotion workflow is added. Large inputs are fetched only on CI.

The pinned SeaweedFS 4.48 TLS/IAM fixture and SDK assertion tests from #103 are
retained. A clean openEuler 22.03 LTS SP4 container installs only those eight
published RPMs and system Java 8. S3A and AWS SDK must come from the installed
RPM closure. Missing classes fail preflight; no replacement JAR is downloaded.
The fixture CA is imported into a temporary JVM trust store. A separate JVM
without that store must fail with a certificate-path validation error.

## Actual assertions

- S3AFileSystem implementation, verified HTTPS, exact small bytes and 12 MiB
  deterministic payload; exact inventory, random seek and copy/delete rename.
- A 5 MiB multipart threshold and part size force a 3-part upload. The independent
  pinned SDK verifies size and the multipart ETag suffix, not just object presence.
- Reader successfully reads, while S3A write and delete fail with a causal AWS
  HTTP status of 403. Generic IO exceptions, 404 and timeouts cannot pass denial.
- Stop/restart the same storage container. Bounded data readiness precedes a
  fresh JVM, which must read both exact payloads and retain reader permissions.
- Delete the S3A prefix; original fixture cleanup then verifies the entire bucket
  is empty. A strict summary requires every phase assertion and multipart proof.

Every service/network wait and Java invocation has a deadline. Workflow ceiling:
20 minutes. Failure uploads server and JVM logs, checksum/package/dependency
records and partial results, excluding the private TLS key and trust store.

This establishes one S3A filesystem profile against one pinned S3 implementation.
It does not claim Spark/Flink lakehouse interoperability, production AWS IAM,
HA/crash recovery, POSIX rename atomicity, or production storage selection.
The next independent profile can consume this endpoint for one lakehouse table.

Primary sources:
- https://hadoop.apache.org/docs/r3.4.3/hadoop-aws/tools/hadoop-aws/connecting.html
- https://github.com/apache/hadoop/blob/rel/release-3.4.3/hadoop-tools/hadoop-aws/pom.xml
