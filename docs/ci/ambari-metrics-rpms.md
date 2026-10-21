# Ambari Metrics RPM acceptance

The RPM workflow consumes source build 39637960371 at commit
`5f1547e79a1d09e50fd006cd2adad237cd93490f`. That successful build compiled
the immutable Apache Metrics 3.0.0 source, verified the Collector entry class,
and checksummed all Collector and preserved Monitor source files. Packaging
requires that exact successful run and verifies its checksums before use.
It does not rebuild Collector Java or replace the Collector with a fixture.

Collector embeds upstream-compatible HBase 2.4.13 and Phoenix 5.1.2.
Their distributions are fetched only on CI, with SHA-512 values pinned from
the official Apache release checksum files. Distribution archives are cached;
each restored archive is checked again before extraction. The Monitor port
records original and converted Python hashes, uses system Python 3/psutil,
and generates runtime JSON from the upstream commented configuration.

Two RPMs install separate Collector and Monitor services. Embedded HBase is
owned by the Collector package. All services run as `ams`, with bounded systemd
stop deadlines and persistent state under `/var/lib`. The Monitor hostname is
resolved on installation, never taken from the build machine. Configuration is
marked `noreplace`; installation does not enable or start services automatically.

The integration job uses a fresh openEuler container, installs both RPMs,
validates systemd unit definitions, and launches their actual service commands
as `ams`. This proves process-level installation/start behavior, not a booted
systemd host. It queries CPU and memory from the real Collector HTTP API with
the host identity and timestamp range. It stops Monitor, Collector and HBase,
starts new processes against the same on-disk state, and requires every captured
historical timestamp/value plus newly collected timestamps after restart.
No synthetic metric submission is used for this acceptance.

Until the installation job actually passes, the RPMs are candidates only.
There is no automatic main merge, repository promotion or release in this PR.
Final repository metadata/checksum promotion follows reviewed runtime evidence.
