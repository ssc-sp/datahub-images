#!/usr/bin/env bats
# shellcheck disable=SC2016

load test_helper

setup() {
	setup_container_test
}

@test "06.01 HashiCorp repository uses a scoped signing key" {
	run run_in_container '
    set -euo pipefail

    repository_file=/etc/apt/sources.list.d/hashicorp.list
    test -r "${repository_file}"

    cat "${repository_file}"

    grep -Fq \
      "signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg" \
      "${repository_file}"

    grep -Fq \
      "https://apt.releases.hashicorp.com" \
      "${repository_file}"

    test -r /usr/share/keyrings/hashicorp-archive-keyring.gpg
  '
	print_test_output

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"https://apt.releases.hashicorp.com"* ]]
}

@test "06.02 Microsoft product repository is temporarily pinned to noble" {
	run run_in_container '
    set -euo pipefail

    repository_file=/etc/apt/sources.list.d/microsoft-prod.list
    test -r "${repository_file}"

    cat "${repository_file}"

    grep -Fq \
      "signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg" \
      "${repository_file}"

    grep -Fq \
      "https://packages.microsoft.com/ubuntu/24.04/prod noble main" \
      "${repository_file}"

    test -r /usr/share/keyrings/microsoft-archive-keyring.gpg
  '
	print_test_output

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"/ubuntu/24.04/prod noble main"* ]]
}

@test "06.03 Azure CLI repository is temporarily pinned to noble" {
	run run_in_container '
    set -euo pipefail

    repository_file=/etc/apt/sources.list.d/azure-cli.list
    test -r "${repository_file}"

    cat "${repository_file}"

    grep -Fq \
      "signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg" \
      "${repository_file}"

    grep -Fq \
      "https://packages.microsoft.com/repos/azure-cli/ noble main" \
      "${repository_file}"
  '
	print_test_output

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"/repos/azure-cli/ noble main"* ]]
}

@test "06.04 addon repositories do not disable signature verification" {
	run run_in_container '
    set -euo pipefail

    if grep -ERi \
      "trusted[[:space:]]*=[[:space:]]*yes|allow-insecure[[:space:]]*=[[:space:]]*yes" \
      /etc/apt/sources.list \
      /etc/apt/sources.list.d 2>/dev/null
    then
      echo "An addon repository disables signature verification." >&2
      exit 1
    fi

    echo "All configured APT repositories retain signature verification."
  '
	print_test_output

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"retain signature verification"* ]]
}
