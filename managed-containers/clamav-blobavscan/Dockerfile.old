FROM ubuntu:24.04@sha256:dc17125eaac86538c57da886e494a34489122fb6a3ebb6411153d742594c2ddc

LABEL org.opencontainers.image.description="ClamAV image used to antivirus scan files"
LABEL org.opencontainers.image.source="https://github.com/ssc-sp/datahub-images"
LABEL org.opencontainers.image.url="https://github.com/ssc-sp/datahub-images/blob/main/managed-containers/clamav-blobavscan/README.md"

ENV DataHub_ENVNAME=dev \
    AzureTenantId= \
    AzureSubscriptionId= \
    AzureWebJobsFeatureFlags=EnableWorkerIndexing \
    AzureWebJobsDashboard= \
    storage_connection_string= \
    queue_name=blob-created \
    container_name=datahub \
    quarantine_container_name=datahub-quarantine \
    DEBIAN_FRONTEND=noninteractive \
    VIRTUAL_ENV=/opt/venv \
    WORK_DIR=/datahub-temp

# Install ca-certificates
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl openssl \
 && rm -rf /var/lib/apt/lists/*

# Install Root CA
ARG GOC_ROOT_A_FINGERPRINT="FE:E0:9E:77:43:BF:D4:3E:D7:D4:D3:ED:50:6C:C7:9D:2D:90:70:FF:A9:29:91:16:87:D4:27:33:70:BE:A3:06"

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl openssl \
    && curl -fsSL --insecure \
        "https://raw.githubusercontent.com/gccloudone-aurora-collab/goc-root-cert-mirror/main/certs/GoC-GdC-Root-A.crt" \
        -o /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt \
    && test "$(openssl x509 -in /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt -noout -sha256 -fingerprint | cut -d= -f2)" = "${GOC_ROOT_A_FINGERPRINT}" \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install all packages from your list
COPY base_packages.list /tmp/base_packages.list
RUN apt-get update \
 && xargs -a /tmp/base_packages.list apt-get install -y --no-install-recommends \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Copy your app
COPY app/ /app/
WORKDIR /app

# Create a venv and install Python deps into it explicitly
RUN python3 -m venv $VIRTUAL_ENV \
 && $VIRTUAL_ENV/bin/pip install --no-cache-dir --upgrade pip \
 && $VIRTUAL_ENV/bin/pip install --no-cache-dir -r requirements.txt

# Final working dir (already /app)
WORKDIR /app

CMD ["bash", "/app/entrypoint.sh"]
