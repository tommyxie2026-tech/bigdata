# Hadoop S3A integration profile

This test-only profile consumes the published Hadoop 3.4.3 and Hadoop client/HDFS/MapReduce/YARN RPMs,
plus Bigtop utils/Groovy/jsvc common packages, at immutable repository commit
`865074386ad88dd82ea9fd043e385e7b1cfe0ca9`. Each RPM is checked against that
commit's SHA256SUMS on the CI runner. No existing RPM is rebuilt. A new optional `bigdata-hadoop-aws-sdk` dependency
RPM packages the upstream SDK binary once; no Java sources are compiled. Large inputs are fetched only on CI.

The pinned SeaweedFS 4.48 TLS/IAM fixture and SDK assertion tests from #103 are
retained. A clean openEuler 22.03 LTS SP4 container installs the eight published RPMs, the new optional SDK RPM, and system Java 8. S3A and AWS SDK must come from the installed RPM closure. The SDK bundle
2.35.4 matches Hadoop 3.4.3 upstream dependency management and is pinned by
SHA-256 `db4b55f24ad1b4e70f17eb1717a4de76a8dadc5a27d764be7c44ff67b2c1c677`.
The published Hadoop RPM lacks this optional bundle; it is supplied through
a separately named dependency RPM, with upstream license material retained.
Missing classes fail preflight; no ad-hoc JAR is copied over the installed package.
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
- Delete all S3A data and require no child entries. The pinned backend removes
  empty directories asynchronously; an independent SDK check may remove only
  the exact zero-byte `s3a/` marker, and rejects every other remaining key.
  It then requires an exact empty prefix inventory. Original fixture cleanup
  verifies the entire bucket is empty. A strict summary requires every phase assertion and multipart proof.

Every service/network wait and Java invocation has a deadline. Integration job ceiling: 20 minutes; optional binary packaging has its own 15-minute ceiling. Failure uploads server and JVM logs, checksum/package/dependency
records and partial results, excluding the private TLS key and trust store.

This establishes one S3A filesystem profile against one pinned S3 implementation.
It does not claim Spark/Flink lakehouse interoperability, production AWS IAM,
HA/crash recovery, POSIX rename atomicity, or production storage selection.
The next independent profile can consume this endpoint for one lakehouse table.

Primary sources:
- https://hadoop.apache.org/docs/r3.4.3/hadoop-aws/tools/hadoop-aws/connecting.html
- https://github.com/apache/hadoop/blob/rel/release-3.4.3/hadoop-tools/hadoop-aws/pom.xml

Packaging reuse: the manual `sdk_package_run_id` input verifies that the referenced packaging job actually succeeded and its package script/contract exactly match current inputs. It then verifies artifact and package-input checksums. Test-only edits do not require repackaging; skipped packaging is reuse, never a new build PASS.

Publication: only a successful mainline integration can create the SDK release candidate and open a repository promotion PR. The candidate includes the exact tested optional RPM, checksums, pinned binary contract and both strict integration reports. Publication remains subject to review/merge; no PR is automatically merged.

Java 8 TLS: use the officially supported `fs.s3a.ssl.channel.mode=default_jsse_with_gcm`. The default S3A Java 8 cipher filter removes GCM and has no common cipher with the fixture server. Enabling normal JSSE GCM preserves both CA and hostname verification; no weak server cipher or insecure trust bypass is enabled. See https://hadoop.apache.org/docs/r3.4.3/hadoop-aws/tools/hadoop-aws/performance.html#Tuning_SSL_Performance.
