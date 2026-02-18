# Pinned to the amd64 build of ubuntu:24.04 for reproducibility and to avoid multi-arch resolution.
# Update digest via: docker buildx imagetools inspect ubuntu:24.04 | grep amd64
FROM ubuntu:24.04@sha256:d1e2e92c075e5ca139d51a140fff46f84315c0fdce203eab2807c7e495eff4f9

LABEL org.opencontainers.image.description="ClamAV image used to antivirus scan files"
LABEL org.opencontainers.image.source="https://github.com/fsdh-pfds/datahub-images"
LABEL org.opencontainers.image.url="https://github.com/fsdh-pfds/datahub-images/blob/main/managed-containers/clamav-blobavscan/README.md"

# Target platform check docker buildx build --platform linux/amd64
ARG TARGETPLATFORM
RUN test "${TARGETPLATFORM:-linux/amd64}" = "linux/amd64" || \
    (echo "ERROR: This image must be built for linux/amd64 (got: ${TARGETPLATFORM:-unset})" >&2; exit 1)

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
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

 # Enable Snapshotting
ARG SNAPSHOT_ID=20250725T145500Z
RUN echo "APT::Snapshot \"${SNAPSHOT_ID}\";" \
     > /etc/apt/apt.conf.d/50snapshot

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
