FROM openeuler/openeuler:22.03-lts-sp4
RUN dnf -y --setopt=timeout=30 --setopt=retries=3 install python3 maven java-1.8.0-openjdk-devel findutils \
    && dnf clean all
COPY policy/ /policy/
COPY pom.xml /fixture/pom.xml
COPY src/ /fixture/src/
WORKDIR /fixture
# Resolve exactly the plugins used by this build, then discard its output.
RUN bash /policy/retry-maven-downloads.sh /online.log mvn -B package \
    && sha256sum target/classes/Smoke.class > /expected-class.sha256 \
    && rm -rf target
ENV MAVEN_NETWORK_MODE=offline
CMD ["bash", "-c", "bash /policy/retry-maven-downloads.sh /offline.log mvn -B package && sha256sum -c /expected-class.sha256 && java -cp target/classes Smoke"]
