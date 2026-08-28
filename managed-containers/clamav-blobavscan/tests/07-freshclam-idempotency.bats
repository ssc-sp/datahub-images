#!/usr/bin/env bats

setup() {
  IMAGE="${IMAGE:-clamav-blobavscan:latest}"
  PLATFORM="${PLATFORM:-linux/amd64}"
  CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
}

@test "07.01 freshclam succeeds when databases are already current" {
  container_script="$(cat <<'SCRIPT'
set -euo pipefail

echo "Running initial freshclam update..."

freshclam \
  --config-file=/etc/clamav/freshclam.conf \
  --stdout

echo
echo "Running freshclam a second time..."

freshclam \
  --config-file=/etc/clamav/freshclam.conf \
  --stdout

echo
echo "Validating signature databases after the second update..."

python3 - <<'PY'
from pathlib import Path
import sys

database_directory = Path("/var/lib/clamav")

required_databases = {
    "main": ("main.cvd", "main.cld"),
    "daily": ("daily.cvd", "daily.cld"),
    "bytecode": ("bytecode.cvd", "bytecode.cld"),
}

errors = []

for database_name, possible_names in required_databases.items():
    available_files = [
        database_directory / name
        for name in possible_names
        if (database_directory / name).is_file()
        and (database_directory / name).stat().st_size > 0
    ]

    if not available_files:
        errors.append(
            f"Missing or empty {database_name} database after "
            "the second freshclam update"
        )
        continue

    database_file = available_files[0]
    print(
        f"PASS: {database_name} database remains usable "
        f"({database_file.name}, {database_file.stat().st_size} bytes)"
    )

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)

    sys.exit(1)

print("Second freshclam update completed successfully.")
print("All required signature databases remain usable.")
PY
SCRIPT
)"

  run "${CONTAINER_RUNTIME}" run \
    --rm \
    --platform "${PLATFORM}" \
    --entrypoint /bin/bash \
    "${IMAGE}" \
    -lc "${container_script}"

  echo "${output}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Second freshclam update completed successfully."* ]]
  [[ "${output}" == *"All required signature databases remain usable."* ]]
}
