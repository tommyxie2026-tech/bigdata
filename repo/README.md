# Tested RPM repository

Successful component release jobs contribute tested runtime RPMs here through a
separate pull request. Packages live once in their owning DNF repository under
`openeuler-22.03-lts-sp4/bigtop-3.6/<component>/<version>/`. Shared Bigtop
runtime packages live in `common/3.6.0/`. Enable `common` and the component's
dependencies as separate DNF repositories: ZooKeeper needs `common`; Hadoop
needs `common` and ZooKeeper; Tez and Hive also need Hadoop. Each directory has
its own `repodata/`, `SHA256SUMS`, and provenance manifest.

Ambari management-plane packages are published separately under
`openeuler-22.03-lts-sp4/ambari/3.0.0/`. That repository contains only the
tested `ambari-server` and `ambari-agent` runtime RPMs and does not share the
Bigtop `common` repository.

The build and test artifacts retain the full RPM set. This repository omits
duplicate dependency copies, source RPMs, debug packages, test packages, docs,
and development headers. A package with the same name built in several jobs
uses the RPM from its owning component's successful test run; build outputs with
the same filename are not assumed to be byte-identical.

RPMs use Git LFS. Clone with Git LFS enabled to obtain the packages rather than
their pointer files. This directory is a versioned repository artifact; it is
not hosted as a public DNF endpoint by GitHub Pages.
