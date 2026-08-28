#!/usr/bin/env bats

setup() {
  IMAGE="${IMAGE:-clamav-blobavscan:latest}"
  PLATFORM="${PLATFORM:-linux/amd64}"
  CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
}

@test "10.01 Government of Canada root certificate fingerprint is correct" {
  container_script="$(cat <<'SCRIPT'
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import hashlib
import ssl
import sys

certificate_path = Path(
    "/usr/local/share/ca-certificates/GoC-GdC-Root-A.crt"
)

expected_fingerprint = (
    "FE:E0:9E:77:43:BF:D4:3E:D7:D4:D3:ED:50:6C:C7:9D:"
    "2D:90:70:FF:A9:29:91:16:87:D4:27:33:70:BE:A3:06"
)
expected_compact = expected_fingerprint.replace(":", "")

if not certificate_path.is_file():
    print(
        f"ERROR: Certificate file is missing: {certificate_path}",
        file=sys.stderr,
    )
    sys.exit(1)

pem_certificate = certificate_path.read_text(encoding="ascii")
der_certificate = ssl.PEM_cert_to_DER_cert(pem_certificate)
actual_compact = hashlib.sha256(der_certificate).hexdigest().upper()
actual_fingerprint = ":".join(
    actual_compact[index:index + 2]
    for index in range(0, len(actual_compact), 2)
)

print(f"Certificate: {certificate_path}")
print(f"SHA-256 fingerprint: {actual_fingerprint}")

if actual_compact != expected_compact:
    print(
        "ERROR: Government of Canada root certificate fingerprint "
        "does not match the expected value.",
        file=sys.stderr,
    )
    sys.exit(1)

print("Government of Canada root certificate fingerprint is correct.")
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
  [[ "${output}" == *"Government of Canada root certificate fingerprint is correct."* ]]
}

@test "10.02 Government of Canada root certificate is trusted by Python" {
  container_script="$(cat <<'SCRIPT'
set -euo pipefail

python3 - <<'PY'
import hashlib
import ssl
import sys

expected_compact = (
    "FE:E0:9E:77:43:BF:D4:3E:D7:D4:D3:ED:50:6C:C7:9D:"
    "2D:90:70:FF:A9:29:91:16:87:D4:27:33:70:BE:A3:06"
).replace(":", "")

context = ssl.create_default_context()
trusted_certificates = context.get_ca_certs(binary_form=True)

trusted_fingerprints = {
    hashlib.sha256(certificate).hexdigest().upper()
    for certificate in trusted_certificates
}

print(f"Trusted CA certificates loaded: {len(trusted_certificates)}")

if expected_compact not in trusted_fingerprints:
    print(
        "ERROR: Government of Canada root certificate is not present "
        "in Python's default trust store.",
        file=sys.stderr,
    )
    sys.exit(1)

print("Government of Canada root certificate is trusted by Python.")
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
  [[ "${output}" == *"Government of Canada root certificate is trusted by Python."* ]]
}
