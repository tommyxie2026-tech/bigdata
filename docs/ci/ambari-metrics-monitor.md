# Metrics Monitor Python 3 adaptation

The Monitor still uses the fixed Metrics 3.0.0 release source (`ce919386e963841ea37f032c5ba6ed9c48298dd8`). Conversion is performed on a separate output tree with pinned fissix 24.4.24. The original and generated SHA256 hashes are recorded per file. Vendored Python 2 psutil is excluded; runtime uses the openEuler `python3-psutil` package.

The port preserves package-relative imports and an executable `main.py`, normalizes the PID path to `/var/run/ambari-metrics-monitor/ambari-metrics-monitor.pid`, updates obsolete threading APIs and retains Python 2's integer minute-bucket semantics. Cross-minute and package-import regression tests exercise converted upstream code.

Independent CI starts the actual Monitor in openEuler, captures repeated fresh CPU/memory emissions, checks its real PID file, stops it gracefully, restarts it and requires fresh emissions again. A temporary HTTP capture fixture is used to isolate the Monitor. Runtime package versions, payload timestamps, port hashes and process logs are retained. Empty/stale/nonfinite/out-of-range samples cannot count as success.

This stage proves Monitor compatibility and collection only after the live job succeeds. It does not prove Collector storage, querying or persistence, and does not itself deliver RPMs. Final delivery still requires both real packages and the actual Collector/Monitor pair's collection/query/restart tests. The Collector source build proceeds independently so Monitor work does not restart Java compilation.
