#!/usr/bin/env bats

setup() {
  IMAGE="${IMAGE:-clamav-blobavscan:latest}"
  PLATFORM="${PLATFORM:-linux/amd64}"
  CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
}

@test "02.01 freshclam downloads ClamAV signature databases" {
  container_script="$(cat <<'SCRIPT'
set -euo pipefail

freshclam \
  --config-file=/etc/clamav/freshclam.conf \
  --stdout

echo
echo "Downloaded signature files:"

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

if not database_directory.is_dir():
    errors.append(
        f"Database directory does not exist: {database_directory}"
    )
else:
    for item in sorted(database_directory.iterdir()):
        if item.is_file():
            print(f"{item.name} - {item.stat().st_size} bytes")

    print()

    for database_name, possible_names in required_databases.items():
        available_files = [
            database_directory / name
            for name in possible_names
            if (database_directory / name).is_file()
        ]

        if not available_files:
            expected_names = ", ".join(possible_names)
            errors.append(
                f"Missing {database_name} database; "
                f"expected one of: {expected_names}"
            )
            continue

        database_file = available_files[0]
        database_size = database_file.stat().st_size

        if database_size <= 0:
            errors.append(f"{database_file.name} is empty")
            continue

        print(
            f"PASS: {database_name} database "
            f"({database_file.name}, {database_size} bytes)"
        )

if errors:
    print(file=sys.stderr)
    print("ClamAV database validation failed:", file=sys.stderr)

    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)

    sys.exit(1)

print()
print("All required ClamAV signature databases were downloaded.")
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
  [[ "${output}" == *"PASS: main database"* ]]
  [[ "${output}" == *"PASS: daily database"* ]]
  [[ "${output}" == *"PASS: bytecode database"* ]]
  [[ "${output}" == *"All required ClamAV signature databases were downloaded."* ]]
}