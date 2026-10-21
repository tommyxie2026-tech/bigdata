# Dedicated open-source dependency caches

The user-approved replacement for Nexus consists of Reposilite 3.6.3 for Maven,
Verdaccio 6.10.6 for npm, and devpi-server 6.20.3 for PyPI behind Caddy TLS.
It needs no Nexus EULA/onboarding action. Published images are pinned by digest;
the devpi image uses a pinned Python base and server version. Build the image
once for the deployment and retain its resulting digest before promotion.

Each service owns a persistent named volume. Maven explicitly stores mirrored
bytes and prioritizes cached content (`STRICT`); npm stores package metadata and
tarballs; devpi stores the PyPI mirror and downloaded files. Public dependency
reads are allowed. The TLS gateway permits only GET/HEAD, npm registration and
publication are disabled, devpi administration is restricted to root with a
random inaccessible initial password, and no backend port is published.
This profile is for public dependency caching, not private artifact publication.

Provide Docker Compose and a managed certificate directory (`PROXY_CERT_DIR`)
containing `tls.crt` and `tls.key`. Set `PROXY_PUBLIC_ORIGIN` to the externally
reachable HTTPS origin so generated npm/PyPI links remain inside the proxy.
The TLS listener binds only to host loopback port 8443. Connect it through an
authorized ingress/tunnel; do not disable certificate verification or expose
backend administration to make it reachable.

Start using `docker compose up -d --build` in this directory. Clients use:

| Client | Endpoint relative to the HTTPS origin |
| --- | --- |
| Maven | `/maven/ci-maven/` |
| npm | `/npm/` |
| pip | `/pypi/root/pypi/+simple/` |

Only set repository `MAVEN_MIRROR_URL`, npm or pip mirror configuration after
validating the actual deployed endpoint. No production server/address has been
provided yet, and this PR does not claim a real deployment or full component
offline build. Existing CI remains online until its complete dependency closure
is proven against that service.

The disposable CI test obtains Maven JUnit, npm is-number and a PyPI six wheel
through verified TLS, compares exact bytes to their official upstreams and
validates npm/PyPI integrity metadata. It physically removes the egress network
from all three servers and checks Docker's actual attached network state.
Cached bytes must remain identical. An uncached Maven version must fail with an
HTTP error while the server stays healthy. All three services then restart on
the same volumes without egress; their cached bytes must still match.

Only `COMPOSE_PROJECT_NAME` ending in `-ci` with `PROXY_DISPOSABLE=1` may run
`verify-cache.sh`. It deliberately disconnects upstream networking and sets the
disposable devpi volume to offline mode. Never run it against production, and
never use `docker compose down --volumes` on a deployed cache you want to keep.
The CI fixture uses a disposable localhost CA; real deployments use managed TLS.

Implementation references: [Reposilite mirrors](https://reposilite.com/guide/mirrors),
[Verdaccio Docker](https://verdaccio.org/docs/docker/),
[Verdaccio configuration](https://verdaccio.org/docs/configuration/), and
[devpi server guide](https://devpi.net/docs/devpi/devpi/stable/+doc/quickstart-server.html).
