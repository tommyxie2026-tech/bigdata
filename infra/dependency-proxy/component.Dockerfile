FROM openeuler/openeuler:22.03-lts-sp4
RUN dnf -y --setopt=timeout=30 --setopt=retries=2 install ca-certificates git java-11-openjdk-devel maven findutils python3 && dnf clean all
