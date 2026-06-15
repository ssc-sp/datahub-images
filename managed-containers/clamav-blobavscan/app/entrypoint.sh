#!/bin/bash
set -euo pipefail

: >"${0}.start"

freshclam --config-file=/etc/clamav/freshclam.conf --stdout

clamd --config-file=/etc/clamav/clamd.conf

python3 scan_blob.py
