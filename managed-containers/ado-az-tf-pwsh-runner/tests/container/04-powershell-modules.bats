#!/usr/bin/env bats

load test_helper

setup() {
  setup_container_test
}

@test "04.01 expected PowerShell module versions are installed" {
  container_script="$(cat <<'SCRIPT'
set -euo pipefail

pwsh -NoLogo -NoProfile -NonInteractive -Command - <<'POWERSHELL'
$ErrorActionPreference = "Stop"

$expectedModules = @{
    Az        = [version]"14.0.0"
    SqlServer = [version]"22.3.0"
}

foreach ($moduleName in $expectedModules.Keys) {
    $expectedVersion = $expectedModules[$moduleName]

    $module = Get-Module -ListAvailable -Name $moduleName |
        Where-Object {
            $_.Version -eq $expectedVersion
        } |
        Select-Object -First 1

    if ($null -eq $module) {
        throw (
            "PowerShell module '{0}' version {1} is not installed." -f
            $moduleName,
            $expectedVersion
        )
    }
}
POWERSHELL

printf '%s\n' "POWERSHELL_MODULE_VERSIONS_OK"
SCRIPT
)"

  run run_in_container "${container_script}"
  print_test_output

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"POWERSHELL_MODULE_VERSIONS_OK"* ]]
}

@test "04.02 representative PowerShell modules can be imported" {
  container_script="$(cat <<'SCRIPT'
set -euo pipefail

pwsh -NoLogo -NoProfile -NonInteractive -Command - <<'POWERSHELL'
$ErrorActionPreference = "Stop"

# Import a representative Az submodule rather than the complete Az roll-up.
Import-Module Az.Accounts -Force -ErrorAction Stop

$null = Get-Command `
    -Name Connect-AzAccount `
    -Module Az.Accounts `
    -ErrorAction Stop

Import-Module SqlServer `
    -RequiredVersion 22.3.0 `
    -Force `
    -ErrorAction Stop

$null = Get-Command `
    -Name Invoke-Sqlcmd `
    -Module SqlServer `
    -ErrorAction Stop
POWERSHELL

printf '%s\n' "POWERSHELL_MODULE_IMPORTS_OK"
SCRIPT
)"

  run run_in_container "${container_script}"
  print_test_output

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"POWERSHELL_MODULE_IMPORTS_OK"* ]]
}