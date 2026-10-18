# Flink CDC PostgreSQL delivery

The independently versioned connector follows the MySQL delivery lifecycle without
changing its workflow or rebuilding existing Flink/Hadoop RPMs.

## Locked inputs

- Component: `flink-cdc-postgres` 3.4.0, upstream commit
  `06581fc73b84b1da45fccf93441d96a118d9bfc1`.
- SQL source module: `flink-sql-connector-postgres-cdc`; target Flink 1.20.1,
  Java 11, openEuler 22.03 LTS SP4.
- Database fixture: PostgreSQL 14.15, image manifest
  `sha256:2a453914efff6156786247b2399e6f9f18d7fc37e1ca5574a23aba172cf37d3e`.
  The database server is never shipped in the connector RPM.
- The upstream shaded JAR includes the PostgreSQL JDBC driver; build and clean
  installation both inspect the JAR for the driver class. This differs from MySQL.
- RPM: `bigdata-flink-cdc-postgres-3.4.0-1.oe2203sp4.noarch.rpm`,
  installed under `/usr/lib/flink/lib/` with upstream LICENSE and NOTICE.

## Build, reuse, test, release

The PR workflow runs select → actual Build RPM (or verified reuse) → actual Test.
On main, successful Test → Release Candidate → repository promotion PR.
Explicit cancellation-aware gates allow RPM reuse without silently skipping
publication. No stage merges a PR.

The selector searches actual successful Build jobs, checks repository ownership,
nonexpired artifact availability, and matching Git blobs for compile/package/
contract/Maven-retry inputs. The package records their identity and the clean
installation test verifies it. Changes confined to tests, harness, documentation
or workflow wiring reuse the RPM; source/package input changes build a new RPM.
An explicit manual rebuild remains available. A skipped Build is never treated as
proof of an actual build; the selected original successful job supplies that proof.
Both source and test Maven dependencies are cached on CI. RPMs and large build
artifacts remain on CI; reviewers need only small evidence and metadata.

## Test method for review

| Phase | Action | Required assertion |
|---|---|---|
| Install | Fresh openEuler container, verify RPM checksum/input identity, install published Flink dependency closure and connector RPM | Exact package name/version/architecture; shaded JDBC class exists |
| Fixture | PostgreSQL with logical WAL, dedicated publication/slot, source table REPLICA IDENTITY FULL | Fixture server version is 14.15 |
| Snapshot | Source rows (1,before), (2,delete-me) | Sink complete row map equals those two rows |
| WAL | Update id 1, delete id 2, insert id 3 | Sink equals (1,after), (3,inserted), no extra rows |
| Checkpoint | Query Flink REST | A real completed checkpoint exists |
| Stop | Stop with savepoint and wait for original job FINISHED | Completed async savepoint has a file path; original job is stopped |
| Slot | Query PostgreSQL replication slots | Dedicated pgoutput slot is inactive with retained restart LSN |
| Offline writes | Update id 1, delete id 3, insert id 4 after original job stopped | Writes occur before submitting recovery job |
| Restore | Submit same job from exact saved path | New JobID, REST restored checkpoint is a savepoint with that exact path |
| Result | Wait for recovery output | Sink equals (1,offline-update), (4,offline-insert), no extra rows |

The test-only JDBC materializer is idempotent and is excluded from the RPM.
It verifies source snapshot/WAL/recovery semantics, not transactional exactly-once
sink delivery or a lakehouse integration. The fixture deliberately delays LSN
acknowledgment so subsequent checkpoints cannot invalidate the tested savepoint.
This is a bounded test retention policy, not production guidance; destroying the
database fixture removes its replication slots/publication.

Evidence includes raw REST responses, original/restored JobIDs, all exact row
assertions, connector JAR entries, database logs and Flink logs. PASS is emitted
only after every assertion. Failed tests upload evidence but no tested-RPM artifact.
The promotion script rechecks phase assertions and RPM checksums, generates
repodata, and records source identity, input identity, original Build/Test run IDs
and contract hash in a v2 manifest. Existing catalog audits do not yet include this
standalone contract; connector-specific evidence remains mandatory.

## Current validation boundary

This PR introduces the workflow; local reuse regression, shell syntax and YAML
validation do not claim a successful source compilation, RPM build, installation
or recovery test. Those gates must succeed in GitHub Actions before release.
No new version is added to the unified component catalog.

Upstream references:
- [PostgreSQL source options](https://nightlies.apache.org/flink/flink-cdc-docs-release-3.4/docs/connectors/flink-sources/postgres-cdc/)
- [Pinned SQL module](https://github.com/apache/flink-cdc/blob/06581fc73b84b1da45fccf93441d96a118d9bfc1/flink-cdc-connect/flink-cdc-source-connectors/flink-sql-connector-postgres-cdc/pom.xml)
