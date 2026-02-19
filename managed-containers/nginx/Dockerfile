# Pinned to specific image
FROM nginx

LABEL org.opencontainers.image.description="NGINX for proxy and web server authentication"
LABEL org.opencontainers.image.source="https://github.com/ssc-sp/datahub-images"
LABEL org.opencontainers.image.url="https://github.com/ssc-sp/datahub-images/blob/main/managed-containers/nginx/README.md"

# Target platform check docker buildx build --platform linux/amd64
ARG TARGETPLATFORM
RUN test "${TARGETPLATFORM:-linux/amd64}" = "linux/amd64" || \
    (echo "ERROR: This image must be built for linux/amd64 (got: ${TARGETPLATFORM:-unset})" >&2; exit 1)

ENV FSDH_ENVNAME=dev \
    FSDH_PROJECT_CD= \
    AzureTenantId= \
    AzureSubscriptionId= \
    FSDH_PORT=8000 \
    FSDH_USER_HEADER_NAME=dh-user \
    FSDH_USER_HEADER_DEFAULT=fsdhuser \
    FSDH_PROXY_TARGET_HOST=localhost \
    FSDH_PROXY_TARGET_PORT=80 \
    FSDH_PROXY_TARGET_PATH=/ \
    DEBIAN_FRONTEND=noninteractive

# Enable Snapshotting
ARG SNAPSHOT_ID=20250725T145500Z

# Install ca-certificates
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY 99-fsdh.sh /docker-entrypoint.d
RUN chmod +x /docker-entrypoint.d/*.sh
