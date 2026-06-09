FROM artifacts-artefacts.devops.cloud-nuage.canada.ca/docker-chainguard-remote/ssc-spc.gc.ca/python:latest-dev AS builder

ARG GOC_ROOT_A_FINGERPRINT="FE:E0:9E:77:43:BF:D4:3E:D7:D4:D3:ED:50:6C:C7:9D:2D:90:70:FF:A9:29:91:16:87:D4:27:33:70:BE:A3:06"
ARG GOC_ROOT_A_URL="https://raw.githubusercontent.com/gccloudone-aurora-collab/goc-root-cert-mirror/main/certs/GoC-GdC-Root-A.crt"

USER root

RUN apk add --no-cache --no-check-certificate ca-certificates curl openssl \
 && curl -fsSL --insecure "${GOC_ROOT_A_URL}" \
    -o /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt \
 && test "$(openssl x509 -in /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt -noout -sha256 -fingerprint | cut -d= -f2)" = "${GOC_ROOT_A_FINGERPRINT}" \
 && update-ca-certificates

ENV VIRTUAL_ENV=/opt/venv

RUN python3 -m venv "$VIRTUAL_ENV"

ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY app/requirements.txt /tmp/requirements.txt

RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r /tmp/requirements.txt

USER nonroot

FROM artifacts-artefacts.devops.cloud-nuage.canada.ca/docker-chainguard-remote/ssc-spc.gc.ca/python-dev:latest-dev AS final

LABEL org.opencontainers.image.description="ClamAV image used to antivirus scan files"
LABEL org.opencontainers.image.source="https://github.com/ssc-sp/datahub-images"
LABEL org.opencontainers.image.url="https://github.com/ssc-sp/datahub-images/blob/main/managed-containers/clamav-blobavscan/README.md"

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
    PATH="/opt/venv/bin:$PATH"

COPY --from=builder /usr/local/share/ca-certificates/ /usr/local/share/ca-certificates/
COPY --from=builder /etc/ssl/certs/ /etc/ssl/certs/

RUN apk add --no-cache \
    clamav \
    clamav-daemon \
    unzip \
    wget

RUN mkdir -p /app "$WORK_DIR" /var/lib/clamav /var/run/clamav /etc/clamav \
 && chown -R nonroot:nonroot \
    /app \
    "$WORK_DIR" \
    /var/lib/clamav \
    /var/run/clamav \
    /etc/clamav

COPY --from=builder --chown=nonroot:nonroot "$VIRTUAL_ENV" "$VIRTUAL_ENV"

COPY --chown=nonroot:nonroot app/ /app/

WORKDIR /app

USER nonroot

CMD ["bash", "/app/entrypoint.sh"]