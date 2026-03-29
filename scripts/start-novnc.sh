#!/usr/bin/env bash
set -euo pipefail

: "${VNC_SERVER_IMPL:=auto}"
: "${REALVNC_LICENSE_KEY:=}"

if [[ "${VNC_SERVER_IMPL}" == "auto" && -n "${REALVNC_LICENSE_KEY}" ]]; then
  VNC_SERVER_IMPL="realvnc"
fi

if [[ "${VNC_SERVER_IMPL}" == "realvnc" ]]; then
  echo "noVNC is disabled when using the RealVNC backend."
  exec sleep infinity
fi

exec /usr/share/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080
