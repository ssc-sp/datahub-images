#!/usr/bin/env bats

load test_helper

setup() {
  setup_container_test
}

@test "02.01 container runs as the non-root runner user" {
  run run_in_container '
    set -euo pipefail

    printf "user=%s uid=%s gid=%s\n" \
      "$(id -un)" \
      "$(id -u)" \
      "$(id -g)"

    test "$(id -un)" = "runner"
    test "$(id -u)" -ne 0
  '
  print_test_output

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"user=runner"* ]]
}

@test "02.02 runner home directory exists and is writable" {
  run run_in_container '
    set -euo pipefail

    test "${HOME}" = "/home/runner"
    test -d "${HOME}"
    test -w "${HOME}"

    temporary_file="${HOME}/.container-write-test"
    printf "ok\n" > "${temporary_file}"
    test -s "${temporary_file}"
    rm -f "${temporary_file}"

    printf "HOME=%s is writable\n" "${HOME}"
  '
  print_test_output

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"HOME=/home/runner is writable"* ]]
}

@test "02.03 operating system is Ubuntu 26.04 resolute" {
  run run_in_container '
    set -euo pipefail

    . /etc/os-release

    printf "ID=%s VERSION_ID=%s VERSION_CODENAME=%s\n" \
      "${ID}" \
      "${VERSION_ID}" \
      "${VERSION_CODENAME}"

    test "${ID}" = "ubuntu"
    test "${VERSION_ID}" = "26.04"
    test "${VERSION_CODENAME}" = "resolute"
  '
  print_test_output

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"ID=ubuntu VERSION_ID=26.04 VERSION_CODENAME=resolute"* ]]
}

@test "02.04 entrypoint exists, is executable, and has valid Bash syntax" {
  run run_in_container '
    set -euo pipefail

    test -f /entrypoint.sh
    test -x /entrypoint.sh
    bash -n /entrypoint.sh

    printf "/entrypoint.sh passed Bash syntax validation\n"
  '
  print_test_output

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"passed Bash syntax validation"* ]]
}

@test "02.05 required baseline commands are available" {
  run run_in_container '
    set -euo pipefail

    for command_name in \
      bash \
      curl \
      gpg \
      lsb_release
    do
      command_path="$(command -v "${command_name}")"
      printf "%s=%s\n" "${command_name}" "${command_path}"
    done
  '
  print_test_output

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"bash="* ]]
  [[ "${output}" == *"curl="* ]]
  [[ "${output}" == *"gpg="* ]]
  [[ "${output}" == *"lsb_release="* ]]
}
