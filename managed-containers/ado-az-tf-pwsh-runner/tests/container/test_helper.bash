setup_container_test() {
	IMAGE="${IMAGE:-ado-az-tf-pwsh-runner:latest}"
	PLATFORM="${PLATFORM:-linux/amd64}"
	EXPECTED_IMAGE_PLATFORM="${EXPECTED_IMAGE_PLATFORM:-${PLATFORM}}"
	CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
}

run_in_container() {
	local script="$1"

	"${CONTAINER_RUNTIME}" run \
		--rm \
		--platform "${PLATFORM}" \
		--entrypoint /bin/bash \
		"${IMAGE}" \
		-lc "${script}"
}

inspect_image() {
	local format="$1"

	"${CONTAINER_RUNTIME}" image inspect \
		"${IMAGE}" \
		--format "${format}"
}

print_test_output() {
	printf '%s\n' "${output}"
}
