# Lifecycle timing and RPM provenance

Timing evidence records the original RPM build and actual test separately from
the observing workflow run. `artifact_reuse_state` distinguishes `fresh`,
`merged_pr`, `verified_repository`, `explicit_rpm` and `unknown`.

- A successful actual Build records the current run as its build origin.
- A selected merged PR records that selected run's actual Build, or its verified
  original RPM producer when Build was skipped. Another workflow's configured
  producer cannot override a successful Build in the selected workflow.
- A verified repository fast path records the manifest's original build and
  tested-artifact run IDs after repository verification and clean installation.
- Explicit RPM retesting records the requested producer and the current actual
  Test run, even if the repository already contains the same component version.

Missing or invalid historical IDs remain null. Skipped and live jobs have no
observed execution duration; a skipped Build never becomes a fresh Build.
Run queue time and individual observed job durations are separate. This report
does not infer Maven/npm/PyPI dependency-cache hits from skipped lifecycle jobs.

These outputs are observational. The checksum, identity, source trust, real
Build/Test and clean-install acceptance gates remain unchanged. Branch CI and a
representative timing artifact must be inspected before claiming the new
provenance propagation works on main.
