FROM artifacts-artefacts.devops.cloud-nuage.canada.ca/docker-chainguard-remote/ssc-spc.gc.ca/python:3.14-dev@sha256:195460197c7894eed2f7155c3cbca73bcc6fc57338de89e42c4dbe3aba9cf135 AS builder

ARG GOC_ROOT_A_FINGERPRINT="FE:E0:9E:77:43:BF:D4:3E:D7:D4:D3:ED:50:6C:C7:9D:2D:90:70:FF:A9:29:91:16:87:D4:27:33:70:BE:A3:06"
ARG GOC_ROOT_A_URL="https://raw.githubusercontent.com/gccloudone-aurora-collab/goc-root-cert-mirror/main/certs/GoC-GdC-Root-A.crt"

USER root

# Required because this stage uses a pipe with openssl | cut
SHELL ["/bin/ash", "-e", "-o", "pipefail", "-c"]

# hadolint ignore=DL3018
RUN apk add --no-cache --no-check-certificate ca-certificates curl openssl \
 && curl -fsSL --insecure "${GOC_ROOT_A_URL}" \
    -o /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt \
 && test "$(openssl x509 -in /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt -noout -sha256 -fingerprint | cut -d= -f2)" = "${GOC_ROOT_A_FINGERPRINT}" \
 && update-ca-certificates

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_NO_COMPILE=1

RUN python3 -m venv "$VIRTUAL_ENV"

COPY app/requirements.txt /tmp/requirements.txt

RUN python3 -m pip install --no-cache-dir --requirement /tmp/requirements.txt

USER nonroot

FROM artifacts-artefacts.devops.cloud-nuage.canada.ca/docker-chainguard-remote/ssc-spc.gc.ca/python:3.14-dev@sha256:195460197c7894eed2f7155c3cbca73bcc6fc57338de89e42c4dbe3aba9cf135 AS runtime-packages

USER root

COPY --from=builder /usr/local/share/ca-certificates/ /usr/local/share/ca-certificates/
COPY --from=builder /etc/ssl/certs/ /etc/ssl/certs/

# hadolint ignore=DL3018
RUN mkdir -p /runtime/etc/apk \
 && cp -r /etc/apk/keys /runtime/etc/apk/keys \
 && cp /etc/apk/repositories /runtime/etc/apk/repositories \
 && apk add --no-cache --initdb --root /runtime --no-scripts \
    bash \
    clamav \
    clamav-daemon \
    unzip \
    wget \
 && rm -rf /runtime/var/cache/apk/* \
 && mkdir -p /runtime/app \
             /runtime/datahub-temp \
             /runtime/var/lib/clamav \
             /runtime/var/run/clamav \
             /runtime/run/clamav \
             /runtime/var/log/clamav \
             /runtime/etc/clamav \
 && chown -R 65532:65532 \
    /runtime/app \
    /runtime/datahub-temp \
    /runtime/var/lib/clamav \
    /runtime/var/run/clamav \
    /runtime/run/clamav \
    /runtime/var/log/clamav \
    /runtime/etc/clamav

COPY clamd.conf /runtime/etc/clamav/clamd.conf
COPY freshclam.conf /runtime/etc/clamav/freshclam.conf

USER nonroot

FROM artifacts-artefacts.devops.cloud-nuage.canada.ca/docker-chainguard-remote/ssc-spc.gc.ca/python:3.14@sha256:28ed0c3de5c583ff972448d50cd6f1dc5547f3cc2167532a05b420743b7dffb5 AS final-base

FROM final-base AS final

LABEL org.opencontainers.image.source="https://github.com/ssc-sp/datahub-images" \
   org.opencontainers.image.url="https://github.com/ssc-sp/datahub-images/blob/main/managed-containers/clamav-blobavscan/README.md" \
   org.opencontainers.image.vendor="GC Secure Artifacts | Artéfacts sécurisés GC https://artifacts-artefacts.devops.cloud-nuage.canada.ca/" \
   org.opencontainers.image.title="ClamAV Blob Scanner" \
   org.opencontainers.image.description="ClamAV image used to antivirus scan files" \
   org.opencontainers.image.authors="SSC Science Program" 

USER root

ENV DataHub_ENVNAME=dev \
    AzureTenantId= \
    AzureSubscriptionId= \
    AzureWebJobsFeatureFlags=EnableWorkerIndexing \
    AzureWebJobsDashboard= \
    storage_connection_string= \
    queue_name=blob-created \
    container_name=datahub \
    quarantine_container_name=datahub-quarantine \
    VIRTUAL_ENV=/opt/venv \
    WORK_DIR=/datahub-temp \
    PATH="/opt/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Copy runtime dependencies
COPY --from=runtime-packages /runtime/ /

# Restore user and group files from the original final base image
COPY --from=final-base /etc/passwd /etc/passwd
COPY --from=final-base /etc/group /etc/group

COPY --from=builder /usr/local/share/ca-certificates/ /usr/local/share/ca-certificates/
COPY --from=builder /etc/ssl/certs/ /etc/ssl/certs/

# Copy Python app
COPY --from=builder --chown=nonroot:nonroot "$VIRTUAL_ENV" "$VIRTUAL_ENV"
COPY --chown=nonroot:nonroot app/ /app/

WORKDIR /app

USER nonroot

ENTRYPOINT []
CMD ["/bin/bash", "/app/entrypoint.sh"]