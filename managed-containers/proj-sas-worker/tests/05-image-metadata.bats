#!/usr/bin/env bats

setup() {
  IMAGE="${IMAGE:-proj-sas-worker:latest}"
  CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
}

@test "05.01 image is configured to run as runner" {
  run "${CONTAINER_RUNTIME}" image inspect \
    "${IMAGE}" \
    --format '{{.Config.User}}'

  echo "${output}"

  [ "${status}" -eq 0 ]
  [ "${output}" = "runner" ]
}

@test "05.02 image uses the SAS worker as its default command" {
  run "${CONTAINER_RUNTIME}" image inspect \
    "${IMAGE}" \
    --format '{{json .Config.Cmd}}'

  echo "${output}"

  [ "${status}" -eq 0 ]
  [ "${output}" = '["pwsh","-f","/app/sas.ps1"]' ]
}

@test "05.03 image platform is linux amd64" {
  run "${CONTAINER_RUNTIME}" image inspect \
    "${IMAGE}" \
    --format '{{.Os}}/{{.Architecture}}'

  echo "${output}"

  [ "${status}" -eq 0 ]
  [ "${output}" = "linux/amd64" ]
}

@test "05.04 expected environment variables are present" {
  run "${CONTAINER_RUNTIME}" image inspect \
    "${IMAGE}" \
    --format '{{range .Config.Env}}{{println .}}{{end}}'

  echo "${output}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"PROJ_CD="* ]]
  [[ "${output}" == *"PROJ_RG="* ]]
  [[ "${output}" == *"PROJ_STORAGE_ACCT="* ]]
  [[ "${output}" == *"PROJ_KV="* ]]
  [[ "${output}" == *"PROJ_SUB="* ]]
  [[ "${output}" == *"CLIENT_ID="* ]]
}
