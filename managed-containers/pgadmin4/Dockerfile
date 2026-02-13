# Pinned to specific image
FROM dpage/pgadmin4

LABEL org.opencontainers.image.description="pgAdmin4 for Postgres Database Web UI"
LABEL org.opencontainers.image.source="https://github.com/fsdh-pfds/datahub-images"
LABEL org.opencontainers.image.url="https://github.com/fsdh-pfds/datahub-images/blob/main/managed-containers/pgadmin4/README.md"

# Target platform check docker buildx build --platform linux/amd64
ARG TARGETPLATFORM
RUN test "${TARGETPLATFORM:-linux/amd64}" = "linux/amd64" || \
    (echo "ERROR: This image must be built for linux/amd64 (got: ${TARGETPLATFORM:-unset})" >&2; exit 1)

ENV FSDH_ENVNAME=dev \
    FSDH_PROJECT_CD= \
    AzureTenantId= \
    AzureSubscriptionId= \
    FSDH_DB_HOST= \
    FSDH_DB_NAME= \
    FSDH_DB_USER= \
    FSDH_DB_PASSWORD= \  
    PGADMIN_SERVER_JSON_FILE=/tmp/servers.json \
    DEBIAN_FRONTEND=noninteractive

# Enable Snapshotting
ARG SNAPSHOT_ID=20250725T145500Z

# Install all packages from your list
COPY base_packages.list /tmp/base_packages.list
USER root
RUN apk update \
    && xargs -a /tmp/base_packages.list apk add

# Copy your app
WORKDIR /pgadmin4
# RUN chown pgadmin4 config.py
RUN sed -i "/AUTHENTICATION_SOURCES/cAUTHENTICATION_SOURCES = ['webserver']" config.py
RUN sed -i "/MASTER_PASSWORD_REQUIRED =/cMASTER_PASSWORD_REQUIRED = False" config.py


