FROM artifacts-artefacts.devops.cloud-nuage.canada.ca/docker-chainguard-remote/ssc-spc.gc.ca/dotnet-sdk:v10-dev@sha256:ac8f4a621726c4f9a6655f9e8d95641d97a0c9ae8755d485db42e84f14ba1bc8 AS builder

ARG GOC_ROOT_A_FINGERPRINT="FE:E0:9E:77:43:BF:D4:3E:D7:D4:D3:ED:50:6C:C7:9D:2D:90:70:FF:A9:29:91:16:87:D4:27:33:70:BE:A3:06" \
    GOC_ROOT_A_URL="https://raw.githubusercontent.com/gccloudone-aurora-collab/goc-root-cert-mirror/main/certs/GoC-GdC-Root-A.crt" \
    SOURCE_REPOSITORY="https://github.com/ssc-sp/guest-inviter-service.git" \
    SOURCE_SHA="37f7845cf6c9f9003321b547648598217f8bb637" \
    BUILD_CONFIGURATION="Release"

ARG CACHE_BUSTER=1

USER root

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# hadolint ignore=DL3018
RUN apk add --no-cache --no-check-certificate ca-certificates curl openssl git \
    && curl -fsSL --insecure "${GOC_ROOT_A_URL}" \
        -o /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt \
    && test "$(openssl x509 -in /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt -noout -sha256 -fingerprint | cut -d= -f2)" = "${GOC_ROOT_A_FINGERPRINT}" \
    && update-ca-certificates \
    && mkdir -p /app \
    && chown nonroot:nonroot /app

WORKDIR /src

RUN mkdir repository \
    && cd repository \
    && git init \
    && git remote add origin "${SOURCE_REPOSITORY}" \
    && git fetch --depth 1 origin "${SOURCE_SHA}" \
    && git checkout FETCH_HEAD \
    && cd .. \
    && test "$(git -C repository rev-parse HEAD)" = "${SOURCE_SHA}" \
    && chown -R nonroot:nonroot /src/repository

USER nonroot

WORKDIR /src/repository/InviterService

RUN dotnet restore "InviterService.csproj" \
    && dotnet publish "InviterService.csproj" \
        --configuration "${BUILD_CONFIGURATION}" \
        --no-restore \
        --output /app/publish \
        /p:UseAppHost=false

FROM artifacts-artefacts.devops.cloud-nuage.canada.ca/docker-chainguard-remote/ssc-spc.gc.ca/aspnet-runtime:v10@sha256:421854898882c5f0e954f5e57107411965b5bb1db6fefced95f3b0138b4bd6b2 AS final

LABEL org.opencontainers.image.source="https://github.com/ssc-sp/datahub-images" \
    org.opencontainers.image.url="https://github.com/ssc-sp/datahub-images/blob/main/managed-containers/guest-inviter-service/README.md" \
    org.opencontainers.image.title="Guest Inviter Service" \
    org.opencontainers.image.description="API backend for FSDH guest invitations" \
    org.opencontainers.image.authors="SSC Science Program" \
    org.opencontainers.image.vendor="GC Secure Artifacts | Artéfacts sécurisés GC https://artifacts-artefacts.devops.cloud-nuage.canada.ca/"

WORKDIR /app

COPY --from=builder /usr/local/share/ca-certificates/ /usr/local/share/ca-certificates/
COPY --from=builder /etc/ssl/certs/ /etc/ssl/certs/

COPY --from=builder --chown=nonroot:nonroot /app/publish .

USER nonroot

EXPOSE 8080
ENV ASPNETCORE_HTTP_PORTS=8080

ENTRYPOINT ["dotnet", "InviterService.dll"]