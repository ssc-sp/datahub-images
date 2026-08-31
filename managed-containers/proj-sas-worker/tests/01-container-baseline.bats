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

@test "01.01 container runs as runner and not root" {
	run run_in_container '
    set -euo pipefail
    printf "user=%s uid=%s\n" "$(id -un)" "$(id -u)"
    test "$(id -un)" = "runner"
    test "$(id -u)" -ne 0
  '

	echo "${output}"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"user=runner"* ]]
}

@test "01.02 required command-line tools are installed" {
	run run_in_container '
    set -euo pipefail

    for command in \
      pwsh \
      curl \
      jq \
      openssl \
      tar \
      gpg \
      lsb_release
    do
      command -v "${command}"
    done
  '

	echo "${output}"
	[ "${status}" -eq 0 ]
}

@test "01.03 SAS worker script exists and is readable" {
	run run_in_container '
    set -euo pipefail
    test -f /app/sas.ps1
    test -r /app/sas.ps1
    printf "SAS worker script is readable\n"
  '

	echo "${output}"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"SAS worker script is readable"* ]]
}
