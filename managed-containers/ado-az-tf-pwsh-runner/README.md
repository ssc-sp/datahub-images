# ADO Linux (Ubuntu) Self‑Hosted Runner

This Docker image provides a ready‑to‑use, self‑hosted Azure DevOps (ADO) runner based on Ubuntu 24.04. It bundles PowerShell, the Azure CLI, and a set of essential command‑line utilities so you can spin up build agents that integrate seamlessly with your GitHub Container Registry and Azure pipelines.

## Key Features

- **Ubuntu 24.04 base** pinned to a SHA256 digest for reproducible builds
- **PowerShell** for cross‑platform scripting
- **Azure CLI** to interact with Azure resources directly from your pipelines
- **Terraform CLI** to interact and deploy terraform resources directly from your pipelines
- Common utilities out of the box:

  - `openssl`, `ca-certificates`
  - `jq`, `curl`, `wget`
  - `gpg`, `lsb-release`, `git`, `debsums`

- Non‑root `runner` user for secure execution
- `entrypoint.sh` to bootstrap any custom startup logic you need

## Getting Started

1. **Pull the image**

   ```bash
   docker pull ghcr.io/fsdh-pfds/ado-az-tf-pwsh-runner:latest
   ```

2. **Run the container**
   Mount your workspace and register the runner with your ADO organization or project:

   ```bash
   docker run -d \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v /home/runner/work:/home/runner/work \
     -e AZP_URL=https://dev.azure.com/your-org \
     -e AZP_TOKEN=<your-pat> \
     -e AZP_AGENT_NAME=my-runner \
     ghcr.io/fsdh-pfds/ado-az-tf-pwsh-runner:latest
   ```

## Environment

- `DEBIAN_FRONTEND=noninteractive` is set to suppress interactive prompts during `apt-get` installs.
- The image exposes no ports by default; it is intended to run as a build agent.

## Metadata & Labels

- **Source:** `https://github.com/fsdh-pfds/datahub-images`
- **Description:** ADO Linux (Ubuntu) Self‑Hosted Runner image with PowerShell and the Azure CLI

These labels conform to the [OCI Image Spec](https://github.com/opencontainers/image-spec):

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/fsdh-pfds/datahub-images"
LABEL org.opencontainers.image.url="https://github.com/fsdh-pfds/datahub-images/blob/main/README.md"
LABEL org.opencontainers.image.description="ADO Linux (ubuntu) Self‑Hosted Runner image with PowerShell and the Azure CLI"
```

## Entrypoint

The container’s entrypoint is `/entrypoint.sh`. Drop any custom initialization or wrapper logic in that script to tailor the runner registration or environment setup.
