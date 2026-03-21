#!/usr/bin/env bash
set -euo pipefail

exec /usr/share/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080
