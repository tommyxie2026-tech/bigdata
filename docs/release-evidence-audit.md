# Release evidence audit

Run the **Audit Release Evidence** workflow for one component or all supported
v2 components: Kafka, Flink, Trino, Iceberg, Hudi, Paimon and Hue.

The audit checks repository RPM LFS object digests, SHA256SUMS and repodata using
the existing repository verifier. It then checks the manifest's original build
run and test run independently, using each run's current attempt and the actual
component/version Build and Test jobs. Failed, skipped or cancelled required
jobs fail the audit. An overall failed/cancelled run with successful required
jobs is reported as a warning; unrelated job results do not invalidate a valid
component build or test.

The small test-evidence artifact is downloaded from the referenced test run.
Its source, compatibility, JDK, profile, version and run IDs must agree with the
manifest. The tested-RPM artifact must also exist and be unexpired. Downloads
are limited to 2 MiB and evidence.md to 128 KiB. RPM payloads are never downloaded,
rebuilt or republished by this workflow.

Scope: this checks GitHub job/artifact provenance and repository content
consistency. It does not independently hash the large tested-RPM artifact against
the repository payload. Older v1 manifests are outside this first audit.
Expired artifacts produce an audit failure, not a request to rebuild published
RPMs; archive evidence permanently before retention expires.

Local regression:
`python3 scripts/ci/test-release-evidence-audit.py`

Authenticated live audit from a checkout with LFS smudge disabled:
`python3 scripts/ci/audit_release_evidence.py --repository OWNER/REPO --component hudi`

The workflow is read-only and independent of component Build/Test/Release.
An audit failure never dispatches a build.

Initial live audit found Kafka 3.4.1 and Flink 1.20.1 v2 manifests lack
compatibility_identity. These are explicit historical evidence gaps, not RPM
build failures. The audit remains failed until the historical evidence is
recovered and verified or an explicit migration policy is reviewed; it does
not invent missing identities or relabel incomplete evidence as success.
