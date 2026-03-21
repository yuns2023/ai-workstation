#!/usr/bin/env bash
set -euo pipefail

: "${USERNAME:=dev}"
: "${DISPLAY:=:1}"

exec su - "${USERNAME}" -c "x11vnc -display ${DISPLAY} -forever -shared -noshm -noxdamage -rfbauth /home/${USERNAME}/.vnc/passwd -rfbport 5900"
