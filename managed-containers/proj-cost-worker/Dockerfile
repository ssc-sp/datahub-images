FROM ubuntu:24.04@sha256:6015f66923d7afbc53558d7ccffd325d43b4e249f41a6e93eef074c9505d2233
LABEL org.opencontainers.image.description="Container Job to calculating resourcegroup costs"
LABEL org.opencontainers.image.source="https://github.com/fsdh-pfds/datahub-images"
LABEL org.opencontainers.image.url="https://github.com/fsdh-pfds/datahub-images/blob/main/managed-containers/proj-cost-worker/README.md"

# Enable headless mode
ENV DEBIAN_FRONTEND=noninteractive
ENV PROJ_CD= PROJ_RG= PROJ_STORAGE_ACCT= PROJ_KV= PROJ_SUB= CLIENT_ID=

COPY base_packages.list /tmp/base_packages.list
COPY addon_packages.list /tmp/addon_packages.list

# Install ca-certificates
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/* 

# apt-get snapshot id
ARG SNAPSHOT_ID=20250912T000000Z
RUN echo "APT::Snapshot \"${SNAPSHOT_ID}\";" \
     > /etc/apt/apt.conf.d/50snapshot

# Install snapshotted baseline packages
RUN apt-get update && \
    xargs -a /tmp/base_packages.list apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install addon repositories    
RUN curl -sSL https://packages.microsoft.com/keys/microsoft.asc -o /tmp/microsoft.gpg && \
    gpg --dearmor < /tmp/microsoft.gpg > /usr/share/keyrings/microsoft-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/ubuntu/$(lsb_release -rs)/prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/microsoft-prod.list && \
    echo "deb [signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/azure-cli.list
  
# Install snapshotted addon packages
RUN apt-get update && \
    xargs -a /tmp/addon_packages.list apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Powershell Modules
RUN pwsh -Command \
    "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop; \
    Install-Module -Name Az -RequiredVersion 14.4.0 -Scope AllUsers -Repository PSGallery -Force -AllowClobber; \
    Install-Module -Name SqlServer -RequiredVersion 22.3.0 -Scope AllUsers -Repository PSGallery -Force -AllowClobber; \
    Install-Module -Name Az.Accounts -RequiredVersion 5.3.0 -Scope AllUsers -Repository PSGallery -Force -AllowClobber; \
    Install-Module -Name Az.ServiceBus -RequiredVersion 4.1.1 -Scope AllUsers -Repository PSGallery -Force -AllowClobber"

# Create unprivileged user
RUN useradd -m -s /bin/bash runner

# Switch to unprivileged user and set entrypoint
USER runner
COPY app/ /app/

CMD ["pwsh", "-f", "/app/cost.ps1"]