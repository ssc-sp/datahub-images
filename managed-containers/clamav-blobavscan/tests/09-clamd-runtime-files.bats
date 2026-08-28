#!/usr/bin/env bats

setup() {
  IMAGE="${IMAGE:-clamav-blobavscan:latest}"
  PLATFORM="${PLATFORM:-linux/amd64}"
  CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
}

@test "09.01 clamd creates its socket pid and log files as nonroot" {
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
echo "Waiting for clamd runtime files..."

python3 - <<'PY'
from pathlib import Path
import stat
import sys
import time

import pyclamd

expected_uid = 65532
expected_gid = 65532

socket_path = Path("/var/run/clamav/clamd.ctl")
pid_path = Path("/var/run/clamav/clamd.pid")
log_path = Path("/var/log/clamav/clamd.log")

last_error = None

for attempt in range(1, 61):
    try:
        clamav_socket = pyclamd.ClamdUnixSocket()

        if clamav_socket.ping() is True:
            print(f"Attempt {attempt}: clamd responded to ping")
            break

        last_error = RuntimeError("clamd returned an unexpected ping result")
    except Exception as error:
        last_error = error
        print(f"Attempt {attempt}: clamd is not ready: {error}")

    time.sleep(1)
else:
    print(
        f"ERROR: pyclamd could not connect to clamd: {last_error}",
        file=sys.stderr,
    )
    sys.exit(1)

errors = []

runtime_files = {
    "socket": socket_path,
    "pid": pid_path,
    "log": log_path,
}

for file_type, path in runtime_files.items():
    if not path.exists():
        errors.append(f"Missing {file_type} path: {path}")
        continue

    file_stat = path.stat()

    if file_type == "socket" and not stat.S_ISSOCK(file_stat.st_mode):
        errors.append(f"Expected a Unix socket at {path}")

    if file_type in {"pid", "log"} and not stat.S_ISREG(file_stat.st_mode):
        errors.append(f"Expected a regular file at {path}")

    if file_stat.st_uid != expected_uid:
        errors.append(
            f"{path} has UID {file_stat.st_uid}; expected {expected_uid}"
        )

    if file_stat.st_gid != expected_gid:
        errors.append(
            f"{path} has GID {file_stat.st_gid}; expected {expected_gid}"
        )

    print(
        f"PASS: {file_type} {path} "
        f"uid={file_stat.st_uid} gid={file_stat.st_gid}"
    )

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)

    if log_path.is_file():
        print("\nclamd log:", file=sys.stderr)
        print(log_path.read_text(errors="replace"), file=sys.stderr)

    sys.exit(1)

print("clamd runtime file test passed.")
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
  [[ "${output}" == *"PASS: socket"* ]]
  [[ "${output}" == *"PASS: pid"* ]]
  [[ "${output}" == *"PASS: log"* ]]
  [[ "${output}" == *"clamd runtime file test passed."* ]]
}
