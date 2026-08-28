#!/usr/bin/env bats

setup() {
  IMAGE="${IMAGE:-clamav-blobavscan:latest}"
  PLATFORM="${PLATFORM:-linux/amd64}"
  CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
}

run_in_container() {
  "${CONTAINER_RUNTIME}" run \
    --rm \
    --platform "${PLATFORM}" \
    --entrypoint /bin/bash \
    "${IMAGE}" \
    -lc "$1"
}

@test "01.01 container runs as the nonroot user" {
  run run_in_container '
    python -c "
import os
print(f\"uid={os.getuid()} gid={os.getgid()}\")
assert os.getuid() == 65532
assert os.getgid() == 65532
"
  '

  echo "${output}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"uid=65532 gid=65532"* ]]
}

@test "01.02 Python is installed" {
  run run_in_container '
    python --version
  '

  echo "${output}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Python 3."* ]]
}

@test "01.03 pip is installed in the virtual environment" {
  run run_in_container '
    pip --version
    command -v pip
  '

  echo "${output}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/opt/venv/"* ]]
}

@test "01.04 Bash is installed" {
  run run_in_container '
    bash --version
  '

  echo "${output}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"GNU bash"* ]]
}

@test "01.05 ClamAV is installed" {
  run run_in_container '
    clamscan --version
  '

  echo "${output}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"ClamAV"* ]]
}

@test "01.06 required runtime directories are writable" {
  run run_in_container '
    set -euo pipefail

    for directory in \
      /datahub-temp \
      /var/lib/clamav \
      /var/run/clamav
    do
      test -d "${directory}"
      test -w "${directory}"
      echo "${directory} is writable"
    done
  '

  echo "${output}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/datahub-temp is writable"* ]]
  [[ "${output}" == *"/var/lib/clamav is writable"* ]]
  [[ "${output}" == *"/var/run/clamav is writable"* ]]
}

@test "01.07 required application files exist" {
  run run_in_container '
    set -euo pipefail

    test -r /clamav-blobavscan/entrypoint.sh
    test -r /clamav-blobavscan/requirements.txt
    test -r /clamav-blobavscan/scan_blob.py

    printf "%s\n" \
      /clamav-blobavscan/entrypoint.sh \
      /clamav-blobavscan/requirements.txt \
      /clamav-blobavscan/scan_blob.py
  '

  echo "${output}"

  [ "${status}" -eq 0 ]
}

@test "01.08 required Python packages can be imported" {
  run run_in_container '
    python -c "
import azure.data.tables
import azure.identity
import azure.storage.blob
import azure.storage.queue
import pyclamd

print(\"Required Python packages imported successfully\")
"
  '

  echo "${output}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Required Python packages imported successfully"* ]]
}