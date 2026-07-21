#!/usr/bin/env bats

load test_helper

setup() {
	setup_container_test
}

@test "03.01 Terraform is installed and starts successfully" {
	run run_in_container '
    set -euo pipefail

    terraform version
    terraform version -json
  '
	print_test_output

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"Terraform v"* ]]
	[[ "${output}" == *'"terraform_version"'* ]]
}

@test "03.02 Azure CLI is installed and starts successfully" {
	run run_in_container '
    set -euo pipefail

    az version --output json
  '
	print_test_output

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
	print_test_output

	[ "${status}" -eq 0 ]
	[[ "${output}" =~ ^[0-9]+\.[0-9]+ ]]
}

@test "03.04 expected Debian packages are installed" {
	run run_in_container '
    set -euo pipefail

    for package_name in \
      azure-cli \
      powershell \
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
	print_test_output

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"azure-cli: install ok installed"* ]]
	[[ "${output}" == *"powershell: install ok installed"* ]]
	[[ "${output}" == *"terraform: install ok installed"* ]]
}
