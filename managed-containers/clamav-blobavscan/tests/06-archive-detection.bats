#!/usr/bin/env bats

setup() {
  IMAGE="${IMAGE:-clamav-blobavscan:latest}"
  PLATFORM="${PLATFORM:-linux/amd64}"
  CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
}

@test "06.01 ClamAV detects EICAR inside a ZIP archive" {
  container_script="$(cat <<'SCRIPT'
set -euo pipefail

echo "Downloading ClamAV signature databases..."

freshclam \
  --config-file=/etc/clamav/freshclam.conf \
  --stdout

echo
echo "Starting clamd..."

clamd \
  --config-file=/etc/clamav/clamd.conf

echo
echo "Waiting for clamd and scanning a ZIP archive..."

python3 - <<'PY'
from pathlib import Path
import sys
import time
import zipfile

import pyclamd

archive_path = Path("/datahub-temp/eicar.zip")
eicar_content = (
    "X5O!P%@AP[4\\PZX54(P^)7CC)7}$"
    "EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"
)

with zipfile.ZipFile(
    archive_path,
    mode="w",
    compression=zipfile.ZIP_DEFLATED,
) as archive:
    archive.writestr("nested/eicar.txt", eicar_content)

print(f"Created archive: {archive_path}")
print(f"Archive size: {archive_path.stat().st_size} bytes")

clamav_socket = None
last_error = None

for attempt in range(1, 61):
    try:
        candidate = pyclamd.ClamdUnixSocket()

        if candidate.ping() is True:
            clamav_socket = candidate
            print(f"Attempt {attempt}: clamd responded to ping")
            break

        last_error = RuntimeError("clamd returned an unexpected ping result")
    except Exception as error:
        last_error = error
        print(f"Attempt {attempt}: clamd is not ready: {error}")

    time.sleep(1)

if clamav_socket is None:
    print(
        f"ERROR: pyclamd could not connect to clamd: {last_error}",
        file=sys.stderr,
    )
    sys.exit(1)

result = clamav_socket.scan_file(str(archive_path))
print(f"Scan result: {result}")

if not result:
    print(
        "ERROR: Expected EICAR detection in the ZIP archive, "
        "but the scan result was empty.",
        file=sys.stderr,
    )
    sys.exit(1)

detections = [
    (status, signature)
    for status, signature in result.values()
    if status == "FOUND"
]

if not detections:
    print(
        f"ERROR: Expected status FOUND, got: {result}",
        file=sys.stderr,
    )
    sys.exit(1)

matching_signatures = [
    signature
    for _, signature in detections
    if "eicar" in signature.lower()
]

if not matching_signatures:
    print(
        f"ERROR: Expected an EICAR signature, got: {result}",
        file=sys.stderr,
    )
    sys.exit(1)

print("Detection status: FOUND")
print(f"Detected signature: {matching_signatures[0]}")
print("ClamAV ZIP archive detection test passed")
PY
SCRIPT
)"

  run "${CONTAINER_RUNTIME}" run \
    --rm \
    --platform "${PLATFORM}" \
    --entrypoint /bin/bash \
    "${IMAGE}" \
    -lc "${container_script}"

  echo "${output}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Detection status: FOUND"* ]]
  [[ "${output}" == *"Detected signature:"*"Eicar"* ]]
  [[ "${output}" == *"ClamAV ZIP archive detection test passed"* ]]
}
