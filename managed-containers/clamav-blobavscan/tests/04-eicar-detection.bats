#!/usr/bin/env bats

setup() {
  IMAGE="${IMAGE:-clamav-blobavscan:latest}"
  PLATFORM="${PLATFORM:-linux/amd64}"
  CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
}

@test "04.01 pyclamd detects the EICAR test file" {
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
echo "Waiting for clamd and scanning EICAR test file..."

python3 - <<'PY'
from pathlib import Path
import sys
import time

import pyclamd

test_file = Path("/datahub-temp/eicar.txt")

test_file.write_text(
    "X5O!P%@AP[4\\PZX54(P^)7CC)7}$"
    "EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*",
    encoding="ascii",
)

print(f"Created test file: {test_file}")
print(f"Test file size: {test_file.stat().st_size} bytes")

last_error = None

for attempt in range(1, 61):
    try:
        clamav_socket = pyclamd.ClamdUnixSocket()

        if not clamav_socket.ping():
            raise RuntimeError("clamd did not respond to ping")

        print(f"Attempt {attempt}: clamd responded to ping")

        result = clamav_socket.scan_file(str(test_file))
        print(f"Scan result: {result}")

        if not result:
            print(
                "ERROR: Expected EICAR detection, but the result was empty.",
                file=sys.stderr,
            )
            sys.exit(1)

        file_result = result.get(str(test_file))

        if not file_result:
            print(
                f"ERROR: Scan result did not contain {test_file}",
                file=sys.stderr,
            )
            sys.exit(1)

        status, signature = file_result

        if status != "FOUND":
            print(
                f"ERROR: Expected status FOUND, got {status!r}",
                file=sys.stderr,
            )
            sys.exit(1)

        if "eicar" not in signature.lower():
            print(
                f"ERROR: Expected an EICAR signature, got {signature!r}",
                file=sys.stderr,
            )
            sys.exit(1)

        print(f"Detection status: {status}")
        print(f"Detected signature: {signature}")
        print("pyclamd EICAR scan test passed")
        sys.exit(0)

    except (ConnectionError, OSError, pyclamd.ConnectionError) as error:
        last_error = error
        print(f"Attempt {attempt}: clamd is not ready: {error}")
        time.sleep(1)

print(
    f"ERROR: pyclamd could not connect to clamd: {last_error}",
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
  [[ "${output}" == *"Detection status: FOUND"* ]]
  [[ "${output}" == *"Detected signature:"*"Eicar"* ]]
  [[ "${output}" == *"pyclamd EICAR scan test passed"* ]]
}