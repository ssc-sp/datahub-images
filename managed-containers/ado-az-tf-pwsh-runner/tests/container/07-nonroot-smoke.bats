#!/usr/bin/env bats

load test_helper

setup() {
  setup_container_test
}

@test "07.01 runner can execute all primary tools without elevated privileges" {
  container_script="$(cat <<'SCRIPT'
set -euo pipefail

test "$(id -u)" -ne 0

terraform version >/tmp/terraform-version.txt
az version --output json >/tmp/azure-cli-version.json

pwsh -NoLogo -NoProfile -NonInteractive -Command '
    $ErrorActionPreference = "Stop"
    Write-Host $PSVersionTable.PSVersion
' >/tmp/powershell-version.txt

test -s /tmp/terraform-version.txt
test -s /tmp/azure-cli-version.json
test -s /tmp/powershell-version.txt

echo "Terraform, Azure CLI, and PowerShell ran successfully as $(id -un)."
SCRIPT
)"

  run run_in_container "${container_script}"
  print_test_output

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"ran successfully as runner"* ]]
}

@test "07.02 runner can write to its home and temporary directories" {
  run run_in_container '
    set -euo pipefail

    for directory in "${HOME}" /tmp
    do
      test -d "${directory}"
      test -w "${directory}"

      test_file="${directory}/container-write-test-$$"
      printf "container test\n" > "${test_file}"
      test -s "${test_file}"
      rm -f "${test_file}"

      printf "%s is writable\n" "${directory}"
    done
  '
  print_test_output

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"/home/runner is writable"* ]]
  [[ "${output}" == *"/tmp is writable"* ]]
}
