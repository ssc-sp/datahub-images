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

@test "03.01 required PowerShell modules are installed at pinned versions" {
	container_script="$(
		cat <<'SCRIPT'
set -euo pipefail

pwsh -NoLogo -NoProfile -NonInteractive -Command - <<'POWERSHELL'
$ErrorActionPreference = "Stop"

$expected = @{
    "Az"            = "14.4.0"
    "SqlServer"     = "22.3.0"
    "Az.Accounts"   = "5.3.0"
    "Az.ServiceBus" = "4.1.1"
}

foreach ($name in $expected.Keys) {
    $version = $expected[$name]

    $module = Get-Module -ListAvailable -Name $name |
        Where-Object { $_.Version -eq [version]$version } |
        Select-Object -First 1

    if (-not $module) {
        Write-Error "$name $version is not installed"
        exit 1
    }

    Write-Output "PASS: $name $version"
}
POWERSHELL
SCRIPT
	)"

	run run_in_container "${container_script}"

	echo "${output}"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"PASS: Az 14.4.0"* ]]
	[[ "${output}" == *"PASS: SqlServer 22.3.0"* ]]
	[[ "${output}" == *"PASS: Az.Accounts 5.3.0"* ]]
	[[ "${output}" == *"PASS: Az.ServiceBus 4.1.1"* ]]
}

@test "03.02 commands required by sas.ps1 are available" {
	container_script="$(
		cat <<'SCRIPT'
set -euo pipefail

pwsh -NoLogo -NoProfile -NonInteractive -Command - <<'POWERSHELL'
$ErrorActionPreference = "Stop"

$commands = @(
    "Set-AzContext",
    "Connect-AzAccount",
    "Get-AzStorageAccount",
    "New-AzStorageContainerSASToken",
    "Get-AzKeyVaultSecret",
    "Set-AzKeyVaultSecret"
)

foreach ($command in $commands) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        Write-Error "Missing required command: $command"
        exit 1
    }

    Write-Output "PASS: $command"
}
POWERSHELL
SCRIPT
	)"

	run run_in_container "${container_script}"

	echo "${output}"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"PASS: Set-AzContext"* ]]
	[[ "${output}" == *"PASS: Connect-AzAccount"* ]]
	[[ "${output}" == *"PASS: Get-AzStorageAccount"* ]]
	[[ "${output}" == *"PASS: New-AzStorageContainerSASToken"* ]]
	[[ "${output}" == *"PASS: Get-AzKeyVaultSecret"* ]]
	[[ "${output}" == *"PASS: Set-AzKeyVaultSecret"* ]]
}
