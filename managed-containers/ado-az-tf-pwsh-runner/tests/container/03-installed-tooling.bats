#!/usr/bin/env bats
# shellcheck disable=SC2016

load test_helper

setup() {
	setup_container_test
}

teardown() {
	print_test_output
}

@test "03.01 Terraform is installed and starts successfully" {
	run run_in_container '
    set -euo pipefail

    terraform version
    terraform version -json
  '

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"Terraform v"* ]]
	[[ "${output}" == *'"terraform_version"'* ]]
}

@test "03.02 Azure CLI is installed and starts successfully" {
	run run_in_container '
    set -euo pipefail

    az version --output json
  '

	[ "${status}" -eq 0 ]
	[[ "${output}" == *'"azure-cli"'* ]]
}

@test "03.03 PowerShell is installed and starts successfully" {
	run run_in_container '
    set -euo pipefail

    pwsh \
      -NoLogo \
      -NoProfile \
      -NonInteractive \
      -Command '\''$PSVersionTable.PSVersion.ToString()'\''
  '

	[ "${status}" -eq 0 ]
	[[ "${output}" =~ ^[0-9]+\.[0-9]+ ]]
}

@test "03.04 expected Debian packages are installed" {
	run run_in_container '
    set -euo pipefail

    for package_name in \
      azure-cli \
      mssql-tools18 \
      powershell \
      python3 \
      python3-pip \
      python3-venv \
      terraform
    do
      package_status="$(
        dpkg-query \
          --show \
          --showformat="\${Status}" \
          "${package_name}"
      )"

      printf "%s: %s\n" "${package_name}" "${package_status}"
      test "${package_status}" = "install ok installed"
    done
  '

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"azure-cli: install ok installed"* ]]
	[[ "${output}" == *"mssql-tools18: install ok installed"* ]]
	[[ "${output}" == *"powershell: install ok installed"* ]]
	[[ "${output}" == *"python3: install ok installed"* ]]
	[[ "${output}" == *"python3-pip: install ok installed"* ]]
	[[ "${output}" == *"python3-venv: install ok installed"* ]]
	[[ "${output}" == *"terraform: install ok installed"* ]]
}

@test "03.05 SQLCMD is installed and starts successfully" {
	run run_in_container '
    set -euo pipefail

    command -v sqlcmd
    sqlcmd -?
  '

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"SQL Server Command Line Tool"* ]]
}
