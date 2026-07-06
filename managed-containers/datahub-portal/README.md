# Datahub Portal – Container Build Guide

This folder contains the Dockerfile used to build and run the **Datahub Portal** container image.

The image is built from a **remote, pinned Git commit** of the `datahub-portal` repository. The Dockerfile does not copy local Datahub Portal source files from the build context anymore. Instead, it fetches the configured commit SHA during the build, verifies that the checked-out commit matches the pinned SHA, then publishes `Portal/src/Datahub.Portal/Datahub.Portal.csproj`.

---

## What this Dockerfile does

The build uses a multi-stage container build:

1. Starts from the internal Chainguard/Wolfi `.NET SDK` image.
2. Installs required build tools: `ca-certificates`, `curl`, `openssl`, and `git`.
3. Downloads and verifies the GoC Root A certificate.
4. Performs a shallow Git fetch of the pinned `SOURCE_SHA`.
5. Builds and publishes the Datahub Portal project.
6. Copies the published output into the internal Chainguard/Wolfi ASP.NET runtime image.
7. Runs the app as `nonroot` on port `8080`.

---

## Source repository tracking

The Dockerfile tracks the remote source using these build arguments:

```dockerfile
ARG SOURCE_REPOSITORY="https://github.com/ssc-sp/datahub-portal.git"
ARG SOURCE_REF="develop"
# renovate: datasource=git-refs depName=datahub-portal packageName=https://github.com/ssc-sp/datahub-portal.git currentValue=develop
ARG SOURCE_SHA="<pinned-commit-sha>"
```

`SOURCE_REPOSITORY` is the remote Git repository.

`SOURCE_REF` is the branch Renovate should track, normally `develop`.

`SOURCE_SHA` is the pinned commit that the image builds from.

The build itself is pinned to `SOURCE_SHA`, not the floating branch. This means the image is reproducible and does not silently change when `develop` moves.

---

## Renovate behaviour

Renovate is expected to manage updates to `SOURCE_SHA`.

The Dockerfile contains a Renovate hint comment:

```dockerfile
# renovate: datasource=git-refs depName=datahub-portal packageName=https://github.com/ssc-sp/datahub-portal.git currentValue=develop
ARG SOURCE_SHA="<pinned-commit-sha>"
```

With a matching `customManagers.regex` configuration, Renovate can check the current HEAD of `develop` and open a pull request when the pinned SHA is behind.

Expected result:

- `SOURCE_REF` stays as `develop`.
- `SOURCE_REPOSITORY` stays unchanged.
- Renovate updates only `SOURCE_SHA`.

Example Renovate custom manager:

```json
{
  "customManagers": [
    {
      "customType": "regex",
      "description": "Update remote Git source SHAs",
      "managerFilePatterns": ["/^managed-containers/.+/Dockerfile$/"],
      "matchStrings": [
        "# renovate: datasource=(?<datasource>\\S+) depName=(?<depName>\\S+) packageName=(?<packageName>\\S+) currentValue=(?<currentValue>\\S+)\\s+ARG SOURCE_SHA=\"(?<currentDigest>[a-f0-9]{40})\""
      ],
      "versioningTemplate": "git"
    }
  ]
}
```

---

## TL;DR – Build and run

Build the image:

```bash
docker build \
  --platform linux/amd64 \
  -f managed-containers/datahub-portal/Dockerfile \
  -t datahub-portal:local \
  .
```

Run the image:

```bash
docker run --rm \
  --platform linux/amd64 \
  --name datahub-portal \
  -p 8080:8080 \
  datahub-portal:local
```

Open:

```text
http://localhost:8080
```

---

## Build commands

### Standard build

```bash
docker build \
  --platform linux/amd64 \
  -f managed-containers/datahub-portal/Dockerfile \
  -t datahub-portal:local \
  .
```

### Clean rebuild

```bash
docker build \
  --no-cache \
  --pull \
  --platform linux/amd64 \
  -f managed-containers/datahub-portal/Dockerfile \
  -t datahub-portal:local \
  .
```

### Verbose BuildKit logs

```bash
DOCKER_BUILDKIT=1 docker build \
  --progress=plain \
  --no-cache \
  --pull \
  --platform linux/amd64 \
  -f managed-containers/datahub-portal/Dockerfile \
  -t datahub-portal:local \
  .
```

### Build a specific remote commit

```bash
docker build \
  --platform linux/amd64 \
  --build-arg SOURCE_SHA="<commit-sha>" \
  --build-arg SOURCE_REF="develop" \
  -f managed-containers/datahub-portal/Dockerfile \
  -t datahub-portal:local \
  .
```

---

## Build context

Unlike the old Dockerfile, this build no longer depends on local `COPY` statements from the Datahub Portal monorepo.

The old model required building from the Datahub Portal repository root because the Dockerfile copied files like:

```dockerfile
COPY Portal/src/Datahub.Portal/ ./Portal/src/Datahub.Portal/
COPY Shared/src/Datahub.Shared/ ./Shared/src/Datahub.Shared/
COPY Directory.Build.props ./
COPY nuget.config ./
```

The new model fetches the source repository directly during the build, so the local build context is no longer used for application source code.

You can still use `.` as the build context from this repository root for consistency with CI.

---

## Base images

The Dockerfile uses internal Chainguard/Wolfi images from GC Secure Artifacts:

```dockerfile
FROM artifacts-artefacts.devops.cloud-nuage.canada.ca/docker-chainguard-remote/ssc-spc.gc.ca/dotnet-sdk:v10-dev AS build
FROM artifacts-artefacts.devops.cloud-nuage.canada.ca/docker-chainguard-remote/ssc-spc.gc.ca/aspnet-runtime:v10 AS final
```

The SDK image is used only for building.

The runtime image is used for the final production container.

The app currently requires .NET 10 because the remote repository’s `global.json` requests a .NET 10 SDK.

---

## Architecture

The image is intended to be built and run as Linux AMD64:

```bash
--platform linux/amd64
```

The .NET runtime identifier is:

```dockerfile
ARG TARGET_RUNTIME="linux-x64"
```

Use both together:

- Docker platform: `linux/amd64`
- .NET RID: `linux-x64`

This avoids platform drift between local development machines and the deployment target.

---

## Running locally

### Minimal run

```bash
docker run --rm \
  --platform linux/amd64 \
  --name datahub-portal \
  -p 8080:8080 \
  datahub-portal:local
```

### Detached run

```bash
docker run -d \
  --platform linux/amd64 \
  --name datahub-portal \
  -p 8080:8080 \
  datahub-portal:local
```

View logs:

```bash
docker logs -f datahub-portal
```

Stop the container:

```bash
docker stop datahub-portal
```

---

## Running with configuration

The app reads configuration from environment variables and `appsettings.*.json`.

Example with environment variables:

```bash
docker run --rm \
  --platform linux/amd64 \
  --name datahub-portal \
  -p 8080:8080 \
  -e ASPNETCORE_ENVIRONMENT=Production \
  -e CONNECTIONSTRINGS__DATAHUB_MSSQL_PROJECT="Server=tcp:<server>.database.windows.net,1433;Database=<db>;Authentication=Active Directory Default;Encrypt=True;" \
  datahub-portal:local
```

Example with a mounted `appsettings.json`:

```bash
docker run --rm \
  --platform linux/amd64 \
  --name datahub-portal \
  -p 8080:8080 \
  -e ASPNETCORE_ENVIRONMENT=Local \
  -v "$(pwd)/your.appsettings.json:/app/appsettings.json:ro" \
  datahub-portal:local
```

---

## Azure authentication notes

For local development, `DefaultAzureCredential` can work if Azure CLI authentication is available inside the container.

Example mount:

```bash
-v "$HOME/.azure:/home/nonroot/.azure:ro"
```

Depending on how the app resolves credentials, you may also need to set environment variables such as:

```bash
-e AZURE_TENANT_ID="<tenant-id>"
-e AZURE_CLIENT_ID="<client-id>"
-e AZURE_CLIENT_SECRET="<client-secret>"
```

Managed Identity is typically for Azure-hosted environments, not local containers.
