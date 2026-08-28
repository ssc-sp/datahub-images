#!/usr/bin/env bats

setup() {
  IMAGE="${IMAGE:-clamav-blobavscan:latest}"
  CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
}

@test "08.01 image runs as nonroot by default" {
  run "${CONTAINER_RUNTIME}" image inspect \
    "${IMAGE}" \
    --format '{{.Config.User}}'

  echo "${output}"

  [ "${status}" -eq 0 ]

  case "${output}" in
    nonroot|65532|65532:65532)
      ;;
    *)
      echo "Expected nonroot or UID 65532, got: ${output}" >&2
      return 1
      ;;
  esac
}

@test "08.02 image uses the expected working directory" {
  run "${CONTAINER_RUNTIME}" image inspect \
    "${IMAGE}" \
    --format '{{.Config.WorkingDir}}'

  echo "${output}"

  [ "${status}" -eq 0 ]
  [ "${output}" = "/clamav-blobavscan" ]
}

@test "08.03 image uses the expected startup command" {
  run "${CONTAINER_RUNTIME}" image inspect \
    "${IMAGE}" \
    --format '{{json .Config.Cmd}}'

  echo "${output}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *'"/bin/bash"'* ]]
  [[ "${output}" == *'"/clamav-blobavscan/entrypoint.sh"'* ]]
}

@test "08.04 image platform is linux amd64" {
  run "${CONTAINER_RUNTIME}" image inspect \
    "${IMAGE}" \
    --format '{{.Os}}/{{.Architecture}}'

  echo "${output}"

  [ "${status}" -eq 0 ]
  [ "${output}" = "linux/amd64" ]
}
