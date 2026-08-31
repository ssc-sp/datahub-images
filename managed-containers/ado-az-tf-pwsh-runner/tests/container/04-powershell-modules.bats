#!/usr/bin/env bats
# shellcheck disable=SC2016

load test_helper

setup() {
	setup_container_test
}

@test "04.01 sas.ps1 contains valid PowerShell syntax" {
	container_script="$(
		cat <<'SCRIPT'
set -euo pipefail

pwsh -NoLogo -NoProfile -NonInteractive -Command - <<'POWERSHELL'
$tokens = $null
$errors = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    "/app/sas.ps1",
    [ref]$tokens,
    [ref]$errors
) | Out-Null

if ($errors.Count -gt 0) {
    $errors | ForEach-Object {
        Write-Error $_.Message
    }

    exit 1
}

Write-Output "PowerShell syntax validation passed"
POWERSHELL
SCRIPT
	)"

	run run_in_container "${container_script}"

	echo "${output}"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"PowerShell syntax validation passed"* ]]
}

@test "04.02 representative PowerShell modules can be imported" {
	container_script="$(
		cat <<'SCRIPT'
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
