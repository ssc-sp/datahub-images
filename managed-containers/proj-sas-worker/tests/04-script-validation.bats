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

@test "04.01 sas.ps1 contains valid PowerShell syntax" {
  run run_in_container '
    pwsh -NoLogo -NoProfile -NonInteractive -Command '\''
      $tokens = $null
      $errors = $null

      [System.Management.Automation.Language.Parser]::ParseFile(
        "/app/sas.ps1",
        [ref]$tokens,
        [ref]$errors
      ) | Out-Null

      if ($errors.Count -gt 0) {
        $errors | ForEach-Object { Write-Error $_.Message }
        exit 1
      }

      Write-Output "PowerShell syntax validation passed"
    '\''
  '

  echo "${output}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"PowerShell syntax validation passed"* ]]
}
