ARG GOC_ROOT_A_FINGERPRINT="FE:E0:9E:77:43:BF:D4:3E:D7:D4:D3:ED:50:6C:C7:9D:2D:90:70:FF:A9:29:91:16:87:D4:27:33:70:BE:A3:06"
ARG GOC_ROOT_A_URL="https://raw.githubusercontent.com/gccloudone-aurora-collab/goc-root-cert-mirror/main/certs/GoC-GdC-Root-A.crt"

ARG SOURCE_REPOSITORY="https://github.com/ssc-sp/datahub-portal.git"
ARG SOURCE_REF="develop"
# renovate: datasource=git-refs depName=datahub-portal packageName=https://github.com/ssc-sp/datahub-portal.git currentValue=develop
ARG SOURCE_SHA="22d88c49d3b58631140841386b4590744056645c"

ARG BUILD_CONFIGURATION="Release"

FROM artifacts-artefacts.devops.cloud-nuage.canada.ca/docker-chainguard-remote/ssc-spc.gc.ca/dotnet-sdk:v10-dev AS build

ARG GOC_ROOT_A_FINGERPRINT \
    GOC_ROOT_A_URL \
    SOURCE_REPOSITORY \
    SOURCE_REF \
    SOURCE_SHA \
    BUILD_CONFIGURATION \
    TARGET_RUNTIME \
    CACHE_BUSTER=1

USER root

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ENV DOTNET_CLI_HOME=/tmp \
    DOTNET_CLI_TELEMETRY_OPTOUT=1

# hadolint ignore=DL3018
RUN apk add --no-cache --no-check-certificate ca-certificates curl openssl git \
    && curl -fsSL --insecure "${GOC_ROOT_A_URL}" \
        -o /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt \
    && test "$(openssl x509 -in /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt -noout -sha256 -fingerprint | cut -d= -f2)" = "${GOC_ROOT_A_FINGERPRINT}" \
    && update-ca-certificates \
    && mkdir -p /src /app/publish \
    && chown -R nonroot:nonroot /app

WORKDIR /src

RUN mkdir repository \
    && git -C repository init \
    && git -C repository remote add origin "${SOURCE_REPOSITORY}" \
    && git -C repository fetch --depth 1 --no-tags origin "${SOURCE_SHA}" \
    && git -C repository checkout --detach FETCH_HEAD \
    && test "$(git -C repository rev-parse HEAD)" = "${SOURCE_SHA}" \
    && chown -R nonroot:nonroot /src/repository

USER nonroot

WORKDIR /src/repository

RUN dotnet restore "Portal/src/Datahub.Portal/Datahub.Portal.csproj" \
        --runtime "${TARGET_RUNTIME}"

RUN dotnet publish "Portal/src/Datahub.Portal/Datahub.Portal.csproj" \
        --runtime "${TARGET_RUNTIME}" \
        --no-restore \
        --self-contained false \
        -p:UseAppHost=false \
        -p:DebugType=None \
        -p:DebugSymbols=false \
        -p:GenerateDocumentationFile=false \
        --configuration "${BUILD_CONFIGURATION}" \
        --output /app/publish

FROM artifacts-artefacts.devops.cloud-nuage.canada.ca/docker-chainguard-remote/ssc-spc.gc.ca/aspnet-runtime:v10 AS final

ARG SOURCE_REPOSITORY \
    SOURCE_REF \
    SOURCE_SHA

LABEL org.opencontainers.image.source="${SOURCE_REPOSITORY}" \
    org.opencontainers.image.revision="${SOURCE_SHA}" \
    org.opencontainers.image.ref.name="${SOURCE_REF}" \
    org.opencontainers.image.url="https://github.com/ssc-sp/datahub-images/blob/main/managed-containers/datahub-portal/README.md" \
    org.opencontainers.image.title="Datahub Portal" \
    org.opencontainers.image.description="Datahub Portal web application" \
    org.opencontainers.image.authors="SSC Science Program" \
    org.opencontainers.image.vendor="GC Secure Artifacts | Artéfacts sécurisés GC https://artifacts-artefacts.devops.cloud-nuage.canada.ca/"

WORKDIR /app

COPY --from=build /usr/local/share/ca-certificates/ /usr/local/share/ca-certificates/
COPY --from=build /etc/ssl/certs/ /etc/ssl/certs/

COPY --from=build --chown=nonroot:nonroot /app/publish ./

USER nonroot

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_EnableDiagnostics=0 \
    ASPNETCORE_HTTP_PORTS=8080 \
    ASPNETCORE_URLS=http://+:8080

EXPOSE 8080

ENTRYPOINT ["dotnet", "Datahub.Portal.dll"]