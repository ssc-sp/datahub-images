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

script_path="$(mktemp --suffix=.ps1)"
trap 'rm -f "${script_path}"' EXIT

cat >"${script_path}" <<'POWERSHELL'
$ErrorActionPreference = "Stop"

$expected = @{
    "Az"            = [version]"14.4.0"
    "SqlServer"     = [version]"22.3.0"
    "Az.Accounts"   = [version]"5.3.0"
    "Az.ServiceBus" = [version]"4.1.1"
}

foreach ($name in $expected.Keys) {
    $expectedVersion = $expected[$name]

    $module = Get-Module -ListAvailable -Name $name |
        Where-Object Version -EQ $expectedVersion |
        Select-Object -First 1

    if (-not $module) {
        $availableVersions = @(
            Get-Module -ListAvailable -Name $name |
                Select-Object -ExpandProperty Version -Unique
        )

        if ($availableVersions.Count -eq 0) {
            throw "$name is not installed"
        }

        throw (
            "$name $expectedVersion is not installed. " +
            "Available versions: $($availableVersions -join ', ')"
        )
    }

    Write-Output "PASS: $name $($module.Version)"
    Write-Output "PATH: $($module.Path)"
}
POWERSHELL

pwsh \
	-NoLogo \
	-NoProfile \
	-NonInteractive \
	-File "${script_path}"
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

@test "03.02 commands required by cost.ps1 are available" {
	container_script="$(
		cat <<'SCRIPT'
set -euo pipefail

script_path="$(mktemp --suffix=.ps1)"
trap 'rm -f "${script_path}"' EXIT

cat >"${script_path}" <<'POWERSHELL'
$ErrorActionPreference = "Stop"

$commands = @(
    "Set-AzContext"
    "Connect-AzAccount"
    "Get-AzStorageAccount"
    "New-AzStorageContainerSASToken"
    "Get-AzKeyVaultSecret"
    "Set-AzKeyVaultSecret"
)

foreach ($commandName in $commands) {
    $command = Get-Command $commandName -ErrorAction SilentlyContinue

    if (-not $command) {
        throw "Missing required command: $commandName"
    }

    Write-Output "PASS: $commandName"
    Write-Output "SOURCE: $($command.Source)"
}
POWERSHELL

pwsh \
	-NoLogo \
	-NoProfile \
	-NonInteractive \
	-File "${script_path}"
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
