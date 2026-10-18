# Flink CDC MySQL delivery

This dedicated workflow targets Flink 1.20.1 / Java 11 on openEuler 22.03 LTS SP4.
The connector source is Flink CDC 3.4.0 release commit
06581fc73b84b1da45fccf93441d96a118d9bfc1. Source compilation run 39097088418
already succeeded. Its checked JAR is repackaged; Java sources are not rebuilt.

## Package boundary

The noarch RPM bigdata-flink-cdc-mysql installs the SQL connector JAR into
/usr/lib/flink/lib and includes upstream LICENSE/NOTICE. The upstream shaded
JAR retains its third-party notices. MySQL Connector/J 8.0.27 is separately
downloaded for the CI fixture and is excluded from the RPM.

The existing Flink 1.20.1, Hadoop 3.4.3 and common runtime RPM repositories are
installed in a fresh openEuler container. Those engine RPMs are not rebuilt.
A MySQL 8.0.36 container enables ROW/FULL binlogs with an explicit server ID.

## Assertions for review

The test-only synchronous JDBC sink materializes the source changelog into a
MySQL table with a primary key. It uses idempotent upserts/deletes; this is not
an exactly-once sink certification.

1. Snapshot: target must equal {1: before, 2: delete-me}.
2. Change source with update(1), delete(2), insert(3). Target must equal
   {1: after, 3: inserted}; partial greps or counts do not pass.
3. Require a completed Flink checkpoint. Stop with a savepoint and require the
   original job to reach FINISHED before making offline database changes.
4. While stopped, update(1), delete(3), insert(4). Restore the same job JAR from
   the recorded savepoint; target must equal {1: offline-update, 4: offline-insert}.
5. The restored job's REST checkpoint metadata must contain is_savepoint=true
   and the exact external_path returned by the stop operation. A fresh snapshot
   that happens to produce the same row set cannot pass as a restore.

REST calls, job submission, assertion polling and cleanup have bounded timeouts.
Failures preserve Flink/MySQL logs, checkpoint/savepoint JSON and submission logs.
Protocol regression:
`python3 scripts/flink-cdc-mysql/test_protocol.py`

## Build reuse and release

The first packaging run creates the connector RPM. Subsequent test-only changes
reuse that successful Build job through rpm_build_run_id and verify its evidence
and RPM checksums. Failed or skipped component tests cannot publish artifacts
named tested-rpms. A skipped Build is only valid when referencing a real,
previously successful connector RPM Build job.

A main-branch run with a real successful Test creates a Release Candidate.
Repository publication requires the tested payload, checksums and repodata,
and a separately reviewed promotion PR; no PR is automatically merged.

The standalone contract is kept with this component while its first delivery
is under review. It does not change the unified component catalog or trigger
unrelated component workflows.

Upstream references:
- https://flink.apache.org/2025/05/16/apache-flink-cdc-3.4.0-release-announcement/
- https://nightlies.apache.org/flink/flink-cdc-docs-release-3.4/docs/connectors/flink-sources/mysql-cdc/
