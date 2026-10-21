# Ambari Metrics delivery

Metrics 3.0.0 is an independent upstream repository, `apache/ambari-metrics`, pinned to release commit `ce919386e963841ea37f032c5ba6ed9c48298dd8`. It is not part of the existing Ambari Server RPM. Target packages are a real Collector and a real Monitor, with clean openEuler installation, timestamped host-metric queries and restart persistence as acceptance criteria.

The first CI stage compiles the Collector entry point with JDK 8 and stores reusable Java output plus dependency checksums. It excludes the unrelated modules and upstream automatic binary-tar downloads. The original recipe otherwise downloads approximately 1.2 GB of HBase, Phoenix and Hadoop archives while building the assembly. Their HTTPS metadata was checked without downloading those large archives locally. Dependency downloads persist across attempts; compiler failures do not trigger transient-network retries.

The source build artifact explicitly identifies its stage as `compile`. It is not an RPM, installation test or release candidate. The Monitor source is preserved without declaring Python 3 support: upstream contains Python 2 imports and syntax, bundled psutil and `/usr/lib/python2.6` service paths. Porting, package assembly and real service tests remain required. The Collector still needs the compatible HBase 2.4.13/Phoenix 5.1.2 runtime, which must be independently pinned and packaged before delivery.

Later packaging must reuse an actual successful unchanged source build, validate its commit and checksums, and produce separate Collector/Monitor RPMs. Release must require real collection/query/restart evidence. Do not mark the component delivered because the compile stage passes.
