# Flink CDC MySQL delivery probe

The first CI run answers whether the upstream MySQL SQL connector can be built
from the immutable 3.4.0 release commit on openEuler 22.03 LTS SP4 with Java 11.
It builds only that Maven module and its reactor dependencies. Existing Flink
1.20.1 and Hadoop RPMs are not rebuilt or downloaded in this phase.

Pinned source: apache/flink-cdc release-3.4.0, commit
06581fc73b84b1da45fccf93441d96a118d9bfc1 (annotated release tag dereferenced).

Upstream compatibility: CDC 3.4 supports Flink 1.19/1.20. The upstream MySQL
source guide supports MySQL 8.0.x and specifies mysql:mysql-connector-java:8.0.27.
That driver is excluded from the upstream connector bundle. The probe fails if
it finds bundled com/mysql classes. The driver will remain a separate test
fixture dependency, outside the Apache connector RPM.

Sources:
- https://flink.apache.org/2025/05/16/apache-flink-cdc-3.4.0-release-announcement/
- https://nightlies.apache.org/flink/flink-cdc-docs-release-3.4/docs/connectors/flink-sources/mysql-cdc/

After the compilation result, extend this dedicated workflow with:
1. A connector-only RPM containing the compiled JAR and upstream licenses.
2. Clean openEuler installation using the existing Flink RPM repository.
3. MySQL 8.0 fixture: assert the exact snapshot row set, then insert/update/delete.
4. Stop with a savepoint, mutate MySQL while stopped, restore, assert exact final
   rows and confirm the restore path through Flink REST checkpoint metadata.
   A fresh successful snapshot cannot substitute for an actual restore.
5. Release candidate and repository promotion PR only after all real tests pass;
   no automatic merges. Test-only changes reuse the connector RPM by source and
   payload digest instead of recompiling it.

The initial feasibility artifact is deliberately not a tested RPM or a release.
