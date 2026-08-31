#!/usr/bin/env bats

setup() {
  IMAGE="${IMAGE:-proj-sas-worker:latest}"
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

@test "02.01 PowerShell 7.5.3 is installed" {
  run run_in_container \
    'pwsh -NoLogo -NoProfile -NonInteractive -Command '\''$PSVersionTable.PSVersion.ToString()'\'''

  echo "${output}"

  [ "${status}" -eq 0 ]
  [ "${output}" = "7.5.3" ]
}

@test "02.02 PowerShell can execute a non-interactive command" {
  run run_in_container \
    'pwsh -NoLogo -NoProfile -NonInteractive -Command '\''Write-Output "PowerShell runtime test passed"'\'''

  echo "${output}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"PowerShell runtime test passed"* ]]
}
