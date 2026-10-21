FROM python:3.12.12-slim-bookworm@sha256:593bd06efe90efa80dc4eee3948be7c0fde4134606dd40d8dd8dbcade98e669c
RUN pip install --disable-pip-version-check --no-cache-dir --timeout 20 --retries 2 devpi-server==6.20.3
COPY devpi-entrypoint.sh /usr/local/bin/proxy-devpi
RUN chmod 755 /usr/local/bin/proxy-devpi && useradd --system --uid 10001 --home-dir /data devpi && mkdir /data && chown devpi /data
USER devpi
ENTRYPOINT ["/usr/local/bin/proxy-devpi"]
