# S3 fixture API integration

This first storage-adapter PR runs a real SeaweedFS S3 server in disposable CI.
It does not deliver a new storage-service RPM or select the production S3 backend.

## Inputs and scope

SeaweedFS 4.48 is pinned to upstream source
`530be3e37337488ecc34d58441e0bc476e121c93` and the official publisher image
`chrislusf/seaweedfs:4.48@sha256:4e61d15fd35994cb1e43e1e553dff106794841fd9a99ade2fc8c8bfce4d7872d`.
Its upstream license is Apache-2.0. The workflow records the actual binary version
and container image ID. The S3 client and transitive dependencies are pinned.

The fixture binds to runner loopback, uses temporary self-signed TLS and public
dummy CI-only identities, and retains filer/volume data in a mounted temporary
directory. The image entrypoint drops to UID/GID 1000; the ephemeral private
key is assigned to that identity with mode 600. A preflight using the same
container UID checks that both key and certificate can be read before startup.
The private key and configuration directory are not uploaded.
Both positive and negative requests use HTTPS; no request disables certificate
verification. The default trust store must reject the fixture certificate,
while explicitly trusting its certificate permits the test.

## Assertions

| Phase | Expected evidence |
|---|---|
| CRUD/list | Exact bytes and object inventory; deleted key returns NoSuchKey/404 |
| Read-only identity | Read succeeds; write denied with an actual S3 403 |
| Invalid key / invalid secret / anonymous | Each denied with an expected authorization error; network errors and 404/500 do not pass |
| TLS | Positive requests verify the configured CA; the untrusted connection raises SSL validation failure |
| Multipart completion | 5 MiB + 1 MiB parts complete; full returned payload SHA-256 matches |
| Multipart abort | Aborted upload no longer appears in upload inventory |
| Restart | Restart container against same data directory; exact retained payload and metadata persist |
| Permission retention | Read-only delete still denied after restart |
| Cleanup | Exact empty inventory, then bucket deletion succeeds |

Every check has bounded client timeouts and retries, phase readiness deadlines
and a workflow deadline. Both initial and restart reports must contain all
required PASS assertions before a final summary can be produced. Logs and
partial evidence are retained on failure. The three local assertion regressions
test false authorization success, duplicate/extra object results and incomplete
PASS reports; the actual server and SDK run on CI.

## Acceptance boundary and next adapter

This is genuine S3 API integration against this pinned implementation, not an
emulated endpoint. Passing it does not establish Hadoop S3A compatibility,
Spark/Flink lakehouse interoperability, Trino catalogs, distributed durability,
HA, production IAM policies or AWS S3 compatibility in general. Those remain
separate acceptance profiles. No existing engine RPM is rebuilt.

The next PR should consume published Hadoop 3.4.3 and its matching hadoop-aws
dependency closure, then exercise persistent remote lakehouse reads/writes with
one engine pair and one table. Credentials, CA propagation, multipart behavior,
restart semantics and unsupported operations must be explicit. Existing local
file-based lakehouse tests cannot substitute for it.

References:
- [Pinned release](https://github.com/seaweedfs/seaweedfs/releases/tag/4.48)
- [Pinned server/TLS flags](https://github.com/seaweedfs/seaweedfs/blob/530be3e37337488ecc34d58441e0bc476e121c93/weed/command/server.go)
- [Pinned S3 credential format](https://github.com/seaweedfs/seaweedfs/blob/530be3e37337488ecc34d58441e0bc476e121c93/weed/command/s3.go)

Restart readiness reads the retained object with a 180-second deadline because bucket metadata can be available before volume registration. Only transport errors and HTTP 500/502/503/504 are retried; authorization errors, missing objects, and byte/checksum mismatches fail immediately.
