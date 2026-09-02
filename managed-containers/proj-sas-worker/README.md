# proj-sas-worker

A minimal, pinned Ubuntu-based container that **rotates an Azure Storage Container SAS** secret stored in **Azure Key Vault** when it’s close to expiry. Intended to run non-interactively (cron/Kubernetes CronJob) using a **Managed Identity**.

---

> **Architecture**: This image **must be built and published as `linux/amd64`**. All build/push commands below include `--platform linux/amd64`. Keep it single‑arch unless you’ve validated multi‑arch at runtime.

---

## What it does

- Reads Key Vault secret **`container-sas`**.
- If its `expiry` tag is **≤ 14 days** out, generates a **new SAS** for container **`datahub`** with `rwd` permissions and a **91‑day** window (start = yesterday, end = +91 days).
- Updates the Key Vault secret value and tags (`start`, `expiry`).

Logic lives in `app/sas.ps1` and is the container’s default command.

---

## Requirements

- Azure Subscription & Key Vault reachable from the workload.
- Storage account containing container `datahub`.
- Runtime identity (system or user‑assigned) with **both**:
  - **Key Vault data‑plane** rights to get/set secrets (RBAC/Access Policy).
  - Rights to **issue SAS** for the target container (either account‑key level or user‑delegation SAS via appropriate roles).

> Lacking storage permissions will fail SAS generation even if Key Vault access is correct.

---

## Image design highlights

- Ubuntu 26.04 pinned by digest + **apt snapshot** via `SNAPSHOT_ID`.
- Package versions pinned in `base_packages.list` / `addon_packages.list`.
- PowerShell + Az modules at fixed versions.
- Runs as **non‑root** user `runner`.

> If you mount extra paths, ensure write permissions for a non‑root user.

---

## Build (amd64)

### Docker Hub

```bash
# login first
echo "$DOCKERHUB_PAT" | docker login -u <your-user> --password-stdin

# build amd64
docker build \
  --platform=linux/amd64 \
  -t <your-user>/proj-sas-worker:latest \
  managed-containers/proj-sas-worker

# push
docker push <your-user>/proj-sas-worker:latest
```

### GitHub Container Registry (buildx, amd64)

```bash
docker buildx create --use --name xbuilder || true

docker buildx build \
  --platform linux/amd64 \
  -t ghcr.io/<org-or-user>/proj-sas-worker:latest \
  managed-containers/proj-sas-worker \
  --push
```

### Local load as amd64 (for testing on ARM Macs)

```bash
docker buildx build \
  --platform linux/amd64 \
  -t <your-user>/proj-sas-worker:dev \
  managed-containers/proj-sas-worker \
  --load
```

### Verify the pushed image is amd64

```bash
docker buildx imagetools inspect <image-ref>
```

> Keep the base image digest current (Renovate hint is present) and update `SNAPSHOT_ID` when advancing apt snapshots.

---

## Run examples

### Local test (system-assigned fallback)

```bash
docker run --rm \
  -e PROJ_CD=abc \
  -e PROJ_RG=rg-xyz \
  -e PROJ_KV=kv-xyz \
  -e PROJ_SUB=<subscription-guid> \
  -e PROJ_STORAGE_ACCT=stxyz \
  <image-ref>
```

---

## Custom trust (optional Root CA)

If you inject at runtime via `ROOT_CA`, the script writes a temporary bundle to `/tmp/custom-root-ca.crt`. Point clients explicitly if needed:

```bash
export CURL_CA_BUNDLE=/tmp/custom-root-ca.crt
export REQUESTS_CA_BUNDLE=/tmp/custom-root-ca.crt
export NODE_EXTRA_CA_CERTS=/tmp/custom-root-ca.crt
```

---

## Logging & exit behavior

- Success: logs current/new expiry and exits `0`.
- Failure (auth, KV, storage): descriptive error + non‑zero exit.

---

## Troubleshooting

- **KV write denied** → verify KV data‑plane RBAC/Access Policy.
- **SAS generation fails** → ensure roles allow account‑key or user‑delegation SAS.
- **TLS errors** → install your Root CA correctly; keep verification **on**.
- **Permission denied** → running as non‑root; fix mounts/ownership or rebuild with `--chown`.

---

## File layout

```none
proj-sas-worker/
├─ Dockerfile                # pinned base + apt snapshot + Az modules
├─ base_packages.list        # minimal pinned packages
├─ addon_packages.list       # addons (PowerShell)
├─ app/
│  └─ sas.ps1               # rotation logic
└─ README.md
```

---

## Security notes

- Keep TLS verification **ON**. Install CAs.
- Non‑root runtime is deliberate; least privilege.
- SAS are secrets—store and surface only via Key Vault.
