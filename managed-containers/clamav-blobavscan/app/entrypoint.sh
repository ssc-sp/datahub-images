#!/bin/bash
set -euo pipefail

: > "${0}.start"

freshclam --config-file=/etc/clamav/freshclam.conf --stdout

clamd --config-file=/etc/clamav/clamd.conf

# shellcheck disable=SC1091
. /opt/venv/bin/activate

python3 scan_blob.py