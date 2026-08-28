#!/usr/bin/env bats

setup() {
  IMAGE="${IMAGE:-clamav-blobavscan:latest}"
  PLATFORM="${PLATFORM:-linux/amd64}"
  CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
}

@test "05.01 pyclamd reports a normal file as clean" {
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
echo "Waiting for clamd and scanning a clean file..."

python3 - <<'PY'
from pathlib import Path
import sys
import time

import pyclamd

test_file = Path("/datahub-temp/clean.txt")
test_file.write_text(
    "This is a normal text file used to verify that ClamAV does not "
    "report clean content as infected.\n",
    encoding="utf-8",
)

print(f"Created clean test file: {test_file}")
print(f"Test file size: {test_file.stat().st_size} bytes")

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

result = clamav_socket.scan_file(str(test_file))
print(f"Scan result: {result}")

if result is None:
    print("Detection status: CLEAN")
    print("pyclamd clean file scan test passed")
    sys.exit(0)

if isinstance(result, dict):
    statuses = [entry[0] for entry in result.values()]

    if statuses and all(status == "OK" for status in statuses):
        print("Detection status: CLEAN")
        print("pyclamd clean file scan test passed")
        sys.exit(0)

print(
    f"ERROR: Expected a clean result, got: {result}",
    file=sys.stderr,
)
sys.exit(1)
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
  [[ "${output}" == *"Detection status: CLEAN"* ]]
  [[ "${output}" == *"pyclamd clean file scan test passed"* ]]
}
