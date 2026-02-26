
# Azure DevOps JWT Generator

This repository contains the configuration to build a minimal, secure container image for an Azure DevOps JWT Generator using [melange](https://github.com/chainguard-dev/melange) and [apko](https://github.com/chainguard-dev/apko).

We use `apko.lock.json` to ensure **100% reproducible builds**. If you build this image today and rebuild it a month from now, the resulting container image digest will be mathematically identical.

## Prerequisites

Ensure you have the following tools installed on your system:
* [melange](https://edu.chainguard.dev/open-source/melange/getting-started-with-melange/) - To build the custom APK package.
* [apko](https://edu.chainguard.dev/open-source/apko/getting-started-with-apko/) - To build the final container image.

---

## 1. Initial Setup (First Time Only)

If you are building this project for the very first time, you need to generate a cryptographic keypair. `melange` requires this to sign the packages, and `apko` uses the public key to verify them.

```bash
# Generate the RSA keypair
melange keygen
```
> **⚠️ IMPORTANT:** This generates `melange.rsa` (Private Key) and `melange.rsa.pub` (Public Key). 
> * **DO** commit `melange.rsa.pub` to version control.
> * **DO NOT** commit `melange.rsa` to version control. Keep it in a secure secret manager. (If you lose this key, future builds will have a different signature, breaking 1:1 reproducibility).

---

## 2. Building the Project

To ensure your builds are bit-for-bit reproducible, you must freeze the filesystem timestamps. We do this by setting `SOURCE_DATE_EPOCH` to the timestamp of the latest Git commit.

Run the following commands to build the package and the container:

```bash
# 1. Freeze the timestamp for reproducible file hashes
export SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct || date +%s)

# 2. Build the local APK package
melange build melange.yaml \
  --arch x86_64 \
  --signing-key melange.rsa

# 3. Build the container image using the lockfile
apko build apko.yaml \
  --lockfile apko.lock.json \
  --keyring-append melange.rsa.pub \
  --arch x86_64 \
  ado-jwt-generator:latest \
  image.tar
```

You can now load the resulting `image.tar` into Docker:
```bash
docker load < image.tar
```

---

## 3. Updating Dependencies (Updating the Lockfile)

The `apko.lock.json` file dictates the exact versions of OS dependencies (like `curl`, `busybox`, etc.) to use. **Do not run the lock command in CI/CD pipelines**, or your builds will drift over time.

You only run the `apko lock` command manually when you deliberately want to update upstream dependencies (e.g., to patch a CVE):

```bash
# 1. Ensure you have built the local package first!
melange build melange.yaml --arch x86_64 --signing-key melange.rsa

# 2. Generate a new lockfile
apko lock apko.yaml \
  --arch x86_64 \
  --keyring-append melange.rsa.pub

# 3. Commit the updated lockfile
git add apko.lock.json
git commit -m "chore: update apko dependencies"
```

---

## Why this workflow? (The "A Month Later" Guarantee)

If you need to rebuild this image a month from now and guarantee the exact same `.tar` hash:
1. **The Code:** `melange` builds `entrypoint.sh` using the same `SOURCE_DATE_EPOCH`, resulting in an identical `.apk`.
2. **The Signature:** Re-using the same `melange.rsa` private key ensures the package signature hasn't changed.
3. **The OS Dependencies:** Using `apko build --lockfile` strictly enforces that `apko` fetches the exact same versions of `busybox`, `curl`, etc., from the Alpine repositories as it did a month ago.
