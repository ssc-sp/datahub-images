# renovate: datasource=docker depName=ubuntu versioning=ubuntu
ARG UBUNTU_VERSION=24.04@sha256:d1e2e92c075e5ca139d51a140fff46f84315c0fdce203eab2807c7e495eff4f9
FROM ubuntu:$UBUNTU_VERSION

# Enable headless mode
ENV DEBIAN_FRONTEND=noninteractive

COPY base_packages.list /tmp/base_packages.list
COPY addon_packages.list /tmp/addon_packages.list

# Install base packages.list
# ./get-versions --list openssl ca-certificates jq curl gpg lsb-release git debsums liblttng-ust1t64 libicu74 wget
RUN apt-get update && \
    xargs -a /tmp/base_packages.list apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install addon repositories    
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg -o /tmp/hashicorp.gpg && \
    gpg --dearmor < /tmp/hashicorp.gpg > /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc -o /tmp/microsoft.gpg && \
    gpg --dearmor < /tmp/microsoft.gpg > /usr/share/keyrings/microsoft-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/ubuntu/$(lsb_release -rs)/prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/microsoft-prod.list && \
    echo "deb [signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/azure-cli.list
  
# Install addon packages.list
RUN apt-get update && \
    xargs -a /tmp/addon_packages.list apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN useradd -m -s /bin/bash runner

# Switch to unprivileged user and set entrypoint
USER runner
ENTRYPOINT ["/entrypoint.sh"]
