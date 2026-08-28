#!/usr/bin/env bats

setup() {
  IMAGE="${IMAGE:-clamav-blobavscan:latest}"
  PLATFORM="${PLATFORM:-linux/amd64}"
  CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
}

@test "03.01 clamd starts and responds through pyclamd" {
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
echo "Waiting for clamd to accept connections..."

python3 - <<'PY'
from pathlib import Path
import sys
import time

import pyclamd

socket_path = Path("/var/run/clamav/clamd.ctl")
last_error = None

for attempt in range(1, 61):
    try:
        clamav_socket = pyclamd.ClamdUnixSocket()
        ping_result = clamav_socket.ping()

        print(f"Attempt {attempt}: pyclamd ping returned {ping_result}")
        print(f"Socket exists: {socket_path.exists()}")

        if ping_result is True:
            print("clamd is running and responding through pyclamd.")
            sys.exit(0)

        last_error = RuntimeError(
            f"Unexpected ping result: {ping_result!r}"
        )
    except Exception as error:
        last_error = error
        print(
            f"Attempt {attempt}: clamd is not ready: {error}"
        )

    time.sleep(1)

print(
    f"ERROR: pyclamd could not connect to clamd: {last_error}",
    file=sys.stderr,
)

log_path = Path("/var/log/clamav/clamd.log")

if log_path.is_file():
    print("\nclamd log:", file=sys.stderr)
    print(log_path.read_text(errors="replace"), file=sys.stderr)

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
  [[ "${output}" == *"pyclamd ping returned True"* ]]
  [[ "${output}" == *"clamd is running and responding through pyclamd."* ]]
}