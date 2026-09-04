FROM ubuntu:26.04@sha256:2260313b31c8c011cd2eebe728008efac1b3982be73eb71348ea2648d2c0e09b AS certificate-builder

ARG GOC_ROOT_A_FINGERPRINT="FE:E0:9E:77:43:BF:D4:3E:D7:D4:D3:ED:50:6C:C7:9D:2D:90:70:FF:A9:29:91:16:87:D4:27:33:70:BE:A3:06"
ARG GOC_ROOT_A_URL="https://raw.githubusercontent.com/gccloudone-aurora-collab/goc-root-cert-mirror/main/certs/GoC-GdC-Root-A.crt"

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-e", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl openssl \
    && curl -fsSL --insecure "${GOC_ROOT_A_URL}" -o /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt \
    && test "$(openssl x509 \
        -in /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt \
        -noout \
        -sha256 \
        -fingerprint \
        | cut -d= -f2)" = "${GOC_ROOT_A_FINGERPRINT}" \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

FROM ubuntu:26.04@sha256:2260313b31c8c011cd2eebe728008efac1b3982be73eb71348ea2648d2c0e09b

LABEL org.opencontainers.image.description="ADO Linux (ubuntu) Self-Hosted Runner image with Terraform, PowerShell and the Azure CLI"
LABEL org.opencontainers.image.source="https://github.com/ssc-sp/datahub-images"
LABEL org.opencontainers.image.url="https://github.com/ssc-sp/datahub-images/blob/main/managed-containers/ado-az-tf-pwsh-runner/README.md"

# Enable headless mode
ENV DEBIAN_FRONTEND=noninteractive

COPY base_packages.list /tmp/base_packages.list
COPY addon_packages.list /tmp/addon_packages.list

# Copy only the fingerprint-verified certificate.
COPY --from=certificate-builder \
    /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt \
    /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt

# Install ca-certificates and rebuild this stage's certificate store.
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Install baseline packages
RUN apt-get update && \
    xargs -a /tmp/base_packages.list apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install addon repositories
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg -o /tmp/hashicorp.gpg && \
    gpg --dearmor < /tmp/hashicorp.gpg > /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o /tmp/microsoft.gpg && \
    gpg --dearmor < /tmp/microsoft.gpg > /usr/share/keyrings/microsoft-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main" > /etc/apt/sources.list.d/microsoft-prod.list && \
    echo "deb [signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/azure-cli/ noble main" > /etc/apt/sources.list.d/azure-cli.list

# Install addon packages
RUN apt-get update && \
    xargs -a /tmp/addon_packages.list apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PowerShell modules
RUN pwsh -Command \
    "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop; \
    Install-Module -Name Az -RequiredVersion 14.0.0 -Scope AllUsers -Repository PSGallery -Force -AllowClobber; \
    Install-Module -Name SqlServer -RequiredVersion 22.3.0 -Scope AllUsers -Repository PSGallery -Force -AllowClobber"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN useradd -m -s /bin/bash runner

# Switch to unprivileged user and set entrypoint properly
USER runner
ENTRYPOINT ["/entrypoint.sh"]