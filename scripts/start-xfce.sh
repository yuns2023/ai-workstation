#!/usr/bin/env bash
set -euo pipefail

: "${USERNAME:=dev}"
: "${DISPLAY:=:1}"
: "${DISPLAY_WIDTH:=1600}"
: "${DISPLAY_HEIGHT:=900}"
: "${DISPLAY_DEPTH:=24}"

export HOME="/home/${USERNAME}"

if ! pgrep -f "Xvfb ${DISPLAY}" >/dev/null 2>&1; then
  Xvfb "${DISPLAY}" -screen 0 "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}" -ac +extension GLX +render -noreset &
  sleep 2
fi

exec su - "${USERNAME}" -c "export DISPLAY=${DISPLAY}; startxfce4"
