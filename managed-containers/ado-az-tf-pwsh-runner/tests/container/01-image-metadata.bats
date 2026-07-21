#!/usr/bin/env bats

load test_helper

setup() {
	setup_container_test
}

@test "01.01 image runs as runner by default" {
	run inspect_image '{{.Config.User}}'
	print_test_output

	[ "${status}" -eq 0 ]
	[ "${output}" = "runner" ]
}

@test "01.02 image uses the expected entrypoint" {
	run inspect_image '{{json .Config.Entrypoint}}'
	print_test_output

	[ "${status}" -eq 0 ]
	[ "${output}" = '["/entrypoint.sh"]' ]
}

@test "01.03 image platform is correct" {
	run inspect_image '{{.Os}}/{{.Architecture}}'
	print_test_output

	[ "${status}" -eq 0 ]
	[ "${output}" = "${EXPECTED_IMAGE_PLATFORM}" ]
}

@test "01.04 image description label is present" {
	run inspect_image '{{index .Config.Labels "org.opencontainers.image.description"}}'
	print_test_output

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"ADO Linux"* ]]
	[[ "${output}" == *"Terraform"* ]]
	[[ "${output}" == *"PowerShell"* ]]
	[[ "${output}" == *"Azure CLI"* ]]
}

@test "01.05 image source label is correct" {
	run inspect_image '{{index .Config.Labels "org.opencontainers.image.source"}}'
	print_test_output

	[ "${status}" -eq 0 ]
	[ "${output}" = "https://github.com/ssc-sp/datahub-images" ]
}

@test "01.06 image URL label is correct" {
	run inspect_image '{{index .Config.Labels "org.opencontainers.image.url"}}'
	print_test_output

	[ "${status}" -eq 0 ]
	[ "${output}" = "https://github.com/ssc-sp/datahub-images/blob/main/managed-containers/ado-az-tf-pwsh-runner/README.md" ]
}
