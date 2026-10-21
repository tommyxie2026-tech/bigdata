# Dedicated dependency proxy

This profile provides Nexus Maven Central, npm and PyPI proxies with persistent storage and a TLS entry point. Images are pinned to immutable registry digests. Nexus's administrative HTTP port and the TLS port bind only to loopback. Expose the TLS endpoint through an authorized ingress or tunnel when a deployment host is available; this profile does not change a host firewall or a repository's mirror settings.

Provide Docker Compose, approximately 4 GB available RAM plus disk capacity for the dependency cache, and a `PROXY_CERT_DIR` containing a managed `tls.crt` and `tls.key` readable by the TLS container. Certificate names must match the public endpoint. Do not disable TLS verification. The CI workflow creates a disposable localhost certificate and explicitly trusts it only for the test.

The pinned Nexus 3.97 Community Edition also requires its upstream telemetry onboarding acknowledgement and ongoing telemetry connectivity. Before production deployment, the operator must review and complete those vendor requirements; this profile does not acknowledge them automatically. See the [official telemetry policy](https://help.sonatype.com/en/nexus-repository-telemetry.html). A blocked-outbound repository test does not disable the server’s separate telemetry service.

Start the profile from this directory with `docker compose up -d`. The `nexus-data` volume holds configuration, metadata and cached bytes across restarts. For a new instance, privately capture the generated password:

```bash
umask 077
docker compose exec -T nexus cat /nexus-data/admin.password > initial-password
python3 configure.py --password-file initial-password \
  --rotate-admin-to .secrets/admin-password
```

Create `.secrets` with mode 0700 before using it. The new password file must not already exist; it is written with mode 0600 before the rotation request so interrupted requests do not lose it. Retain the original private file until rotation and authenticated configuration succeed, then delete the original. Existing deployments use their current administrative password file instead. Never commit password/certificate files or put credentials in mirror URLs.

Configuration creates only dedicated `ci-maven`, `ci-npm`, `ci-pypi` proxy repositories and refuses name collisions with another format/type. Re-running updates their declared settings. Public anonymous reads are opt-in (`--allow-anonymous`) for an instance dedicated exclusively to public dependencies. For private access, keep anonymous access disabled and provision read-only credentials through the normal secret-management process; do not use the administrative account in builds.

Client endpoints after the real TLS origin is assigned:

| Client | Path |
| --- | --- |
| Maven | `/repository/ci-maven/` |
| npm | `/repository/ci-npm/` |
| pip | `/repository/ci-pypi/simple/` |

Set `MAVEN_MIRROR_URL` to the verified HTTPS Maven endpoint only after deployment validation. Existing Maven policy supports credentials under server ID `ci-dependency-mirror` in private settings. Do not cache settings files. npm/pip client configuration and a full component's offline dependency closure still need separate validation before those builds are switched over.

`dependency-proxy.yml` exercises a disposable instance: configure public proxies, rotate the initial admin password, retrieve a cold Maven artifact through TLS, compare it with the HTTPS upstream, block proxy outbound connections, verify cached retrieval and missing-artifact failure, restart Nexus and verify cached bytes again. Evidence retains SHA256 checksums and logs. `verify-cache.sh` deliberately blocks the dedicated repositories and must only be used against the disposable test instance. It does not prove a full component build or production availability.

Do not run `docker compose down --volumes` on a deployed cache unless intentionally discarding it; CI does this only for its temporary instance. Real deployment, mirror activation and representative cold/warm/offline component builds remain pending an authorized host/address.

API definitions follow the [official Nexus REST reference](https://help.sonatype.com/en/api-reference.html). Upstream proxy origins are the official HTTPS Maven Central, npm and PyPI services. Image digests were verified from registry metadata; upgrades must be separately pinned and tested.
