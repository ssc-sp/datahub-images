FROM curlimages/curl:latest@sha256:4026b29997dc7c823b51c164b71e2b51e0fd95cce4601f78202c513d97da2922 AS downloader

ARG RUNNER_VERSION=2.327.1
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.7.0
ARG DOCKER_VERSION=28.3.2
ARG BUILDX_VERSION=0.26.1

WORKDIR /tmp/actions-runner

# Actions Runner (linux + x64 only)
RUN curl -fsSL -o runner.tar.gz \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    && tar xzf runner.tar.gz \
    && rm runner.tar.gz

WORKDIR /tmp/docker

# Docker Engine static binaries (x86_64)
RUN curl -fsSL -o docker.tgz \
    "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" \
    && tar xzf docker.tgz \
    && rm docker.tgz

WORKDIR /tmp/buildx

# Buildx (linux-amd64)
RUN curl -fsSL -o docker-buildx \
    "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-amd64" \
    && chmod +x docker-buildx


FROM ubuntu:24.04@sha256:a08e551cb33850e4740772b38217fc1796a66da2506d312abe51acda354ff061

LABEL org.opencontainers.image.description="ADO Linux (ubuntu) Self‑Hosted Runner image with Terraform, PowerShell and the Azure CLI"
LABEL org.opencontainers.image.source="https://github.com/fsdh-pfds/datahub-images"
LABEL org.opencontainers.image.url="https://github.com/fsdh-pfds/datahub-images/blob/main/managed-containers/ado-az-tf-pwsh-runner/README.md"

ARG SNAPSHOT_ID=20250725T181600Z

# Enable headless mode
ENV DEBIAN_FRONTEND=noninteractive \
    RUNNER_MANUALLY_TRAP_SIG=1 \
    ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1 \
    ImageOS=ubuntu24

COPY base_packages.list /tmp/base_packages.list
COPY addon_packages.list /tmp/addon_packages.list

# Install ca-certificates
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/* 

# apt-get snapshot id
RUN echo "APT::Snapshot \"${SNAPSHOT_ID}\";" \
     > /etc/apt/apt.conf.d/50snapshot

# Install snapshotted baseline packages
RUN apt-get update && \
    xargs -a /tmp/base_packages.list apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Addiong additional repositories and keys 
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg -o /tmp/hashicorp.gpg && \
    gpg --dearmor < /tmp/hashicorp.gpg > /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc -o /tmp/microsoft.gpg && \
    gpg --dearmor < /tmp/microsoft.gpg > /usr/share/keyrings/microsoft-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/ubuntu/$(lsb_release -rs)/prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/microsoft-prod.list && \
    echo "deb [signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/azure-cli.list && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key -o /tmp/nodesource.gpg && \
    gpg --dearmor < /tmp/nodesource.gpg > /usr/share/keyrings/nodesource-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/nodesource-archive-keyring.gpg] https://deb.nodesource.com/node_24.x nodistro main" > /etc/apt/sources.list.d/nodesource.list

# Install snapshotted addon packages
RUN apt-get update && \
    xargs -a /tmp/addon_packages.list apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create runner user and set permissions    
RUN adduser --disabled-password --gecos "" --uid 1001 runner \
    && groupadd docker --gid 123 \
    && usermod -aG sudo,docker runner \
    && echo "%sudo ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-runner \
    && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers.d/99-runner \
    && chmod 440 /etc/sudoers.d/99-runner

WORKDIR /home/runner

COPY --chown=runner:docker entrypoint.sh .
COPY --chown=runner:docker --from=downloader  /tmp/actions-runner .
COPY --from=downloader /tmp/buildx/docker-buildx /usr/bin/
COPY --from=downloader /tmp/docker/* /usr/bin/


# Switch to unprivileged user and set entrypoint
USER runner
ENTRYPOINT ["./entrypoint.sh"]