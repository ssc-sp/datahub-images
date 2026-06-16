FROM cgr.dev/chainguard/dotnet-sdk:latest-dev AS builder

ARG GOC_ROOT_A_FINGERPRINT="FE:E0:9E:77:43:BF:D4:3E:D7:D4:D3:ED:50:6C:C7:9D:2D:90:70:FF:A9:29:91:16:87:D4:27:33:70:BE:A3:06"
ARG GOC_ROOT_A_URL="https://raw.githubusercontent.com/gccloudone-aurora-collab/goc-root-cert-mirror/main/certs/GoC-GdC-Root-A.crt"

ARG SOURCE_REPOSITORY="https://github.com/ssc-sp/guest-inviter-service.git"
ARG SOURCE_REF="main"
ARG BUILD_CONFIGURATION="Release"

ARG CACHE_BUSTER=1

USER root

RUN apk add --no-cache --no-check-certificate ca-certificates curl openssl git \
 && curl -fsSL --insecure "${GOC_ROOT_A_URL}" \
    -o /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt \
 && test "$(openssl x509 -in /usr/local/share/ca-certificates/GoC-GdC-Root-A.crt -noout -sha256 -fingerprint | cut -d= -f2)" = "${GOC_ROOT_A_FINGERPRINT}" \
 && update-ca-certificates

RUN mkdir -p /app && chown nonroot:nonroot /app

WORKDIR /src

RUN git clone \
        --depth 1 \
        --branch "${SOURCE_REF}" \
        "${SOURCE_REPOSITORY}" \
        repository \
    && chown -R nonroot:nonroot /src/repository

# 4. Switch to nonroot for the actual .NET build
USER nonroot

WORKDIR /src/repository/InviterService

RUN dotnet restore "InviterService.csproj"

# 5. This will now work because nonroot owns /app
RUN dotnet publish "InviterService.csproj" \
    --configuration "${BUILD_CONFIGURATION}" \
    --no-restore \
    --output /app/publish \
    /p:UseAppHost=false

FROM cgr.dev/chainguard/aspnet-runtime:latest AS final

LABEL org.opencontainers.image.description="Guest Inviter Service"
LABEL org.opencontainers.image.source="https://github.com/ssc-sp/datahub-images"
LABEL org.opencontainers.image.url="https://github.com/ssc-sp/datahub-images/blob/main/managed-containers/guest-inviter-service/README.md"

WORKDIR /app

COPY --from=builder /usr/local/share/ca-certificates/ /usr/local/share/ca-certificates/
COPY --from=builder /etc/ssl/certs/ /etc/ssl/certs/

COPY --from=builder --chown=nonroot:nonroot /app/publish .

USER nonroot

EXPOSE 8080
ENV ASPNETCORE_HTTP_PORTS=8080

ENTRYPOINT ["dotnet", "InviterService.dll"]