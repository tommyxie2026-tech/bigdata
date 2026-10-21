# Ambari Metrics reviewed release

This flow does not build another Collector or Monitor. It takes the original
successful RPM packaging run and an actual successful clean openEuler acceptance
run from `.github/workflows/ambari-metrics-rpms.yml`.

The release workflow runs contracts on PRs. Candidate generation and repository
PR creation require an explicit manual dispatch on main, after this workflow and
the exact tested packaging recipe have been reviewed and merged. Supply
`package_run_id` and `test_run_id`; these must be the original successful jobs,
not a source-build run or a preflight. Failed, skipped and live installation jobs
cannot satisfy acceptance. A skipped packaging job is allowed only when its
selector and fixed workflow input prove reuse of the supplied original producer.

`assemble.py` checks same-repository job provenance, identical packaging inputs,
identical acceptance logic, both RPM digests and actual CPU/memory query evidence.
All three services must have different PIDs after restart, historical samples
must survive, and both metric streams must contain fresh samples. RPM headers
are checked inside openEuler on CI. No large RPM artifact needs to be downloaded
on the developer machine.

The candidate retains original build/test IDs, immutable upstream source,
packaging identity, package digests and original evidence. Promotion copies these
payloads to the split RPM repository, generates and verifies checksum/primary
metadata, requires Git LFS for RPMs and opens a separate review PR. It never merges
that PR. Existing versions are rejected rather than overwritten; a changed
published payload requires a reviewed release revision.

Local parser/workflow tests do not prove a working Collector. Delivery remains
incomplete until actual installation/restart CI passes, the candidate validates,
and the RPM repository PR is reviewed, merged and verified after publication.
