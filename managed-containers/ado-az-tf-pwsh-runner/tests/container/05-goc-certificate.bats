#!/usr/bin/env bats

load test_helper

setup() {
  setup_container_test
}

@test "05.01 Government of Canada root certificate fingerprint is correct" {
  container_script="$(cat <<'SCRIPT'
set -euo pipefail

pwsh -NoLogo -NoProfile -NonInteractive -Command - <<'POWERSHELL'
$ErrorActionPreference = "Stop"

$certificatePath = "/usr/local/share/ca-certificates/GoC-GdC-Root-A.crt"
$expectedFingerprint = (
    "FE:E0:9E:77:43:BF:D4:3E:D7:D4:D3:ED:50:6C:C7:9D:" +
    "2D:90:70:FF:A9:29:91:16:87:D4:27:33:70:BE:A3:06"
)
$expectedCompact = $expectedFingerprint.Replace(":", "")

if (-not (Test-Path -LiteralPath $certificatePath -PathType Leaf)) {
    throw "Certificate file is missing: $certificatePath"
}

$certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
    $certificatePath
)
$actualCompact = $certificate.GetCertHashString(
    [System.Security.Cryptography.HashAlgorithmName]::SHA256
)
$actualFingerprint = [regex]::Replace(
    $actualCompact,
    "(.{2})(?!$)",
    '$1:'
)

Write-Host "Certificate: $certificatePath"
Write-Host "SHA-256 fingerprint: $actualFingerprint"

if ($actualCompact -ne $expectedCompact) {
    throw (
        "Government of Canada root certificate fingerprint is " +
        "$actualFingerprint; expected $expectedFingerprint."
    )
}

Write-Host "Government of Canada root certificate fingerprint is correct."
POWERSHELL
SCRIPT
)"

  run run_in_container "${container_script}"
  print_test_output

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Government of Canada root certificate fingerprint is correct."* ]]
}

@test "05.02 Government of Canada root certificate is in Ubuntu CA bundle" {
  container_script="$(cat <<'SCRIPT'
set -euo pipefail

pwsh -NoLogo -NoProfile -NonInteractive -Command - <<'POWERSHELL'
$ErrorActionPreference = "Stop"

$certificatePath = "/usr/local/share/ca-certificates/GoC-GdC-Root-A.crt"
$bundlePath = "/etc/ssl/certs/ca-certificates.crt"

$certificatePem = (
    [System.IO.File]::ReadAllText($certificatePath) -replace "`r`n", "`n"
).Trim()

$bundlePem = (
    [System.IO.File]::ReadAllText($bundlePath) -replace "`r`n", "`n"
)

if (-not $bundlePem.Contains($certificatePem)) {
    throw (
        "Government of Canada root certificate is not present in " +
        "Ubuntu's generated CA bundle."
    )
}

Write-Host "Government of Canada root certificate is present in Ubuntu's CA bundle."
POWERSHELL
SCRIPT
)"

  run run_in_container "${container_script}"
  print_test_output

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Government of Canada root certificate is present in Ubuntu's CA bundle."* ]]
}
