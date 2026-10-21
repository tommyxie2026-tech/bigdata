#!/bin/sh
set -eu
if [ ! -f /data/.serverversion ]; then
  # No admin password is exposed: the read-only TLS gateway rejects mutations.
  devpi-init --serverdir=/data --root-passwd="$(python -c 'import secrets;print(secrets.token_urlsafe(48))')"
fi
if [ -f /data/offline ]; then
  set -- --offline-mode
fi
exec devpi-server --serverdir=/data --host=0.0.0.0 --port=3141 --request-timeout=15 --restrict-modify=root "$@"
