#!/usr/bin/env bash
set -euo pipefail

: "${USERNAME:=dev}"
: "${HOME_DIR:=/home/${USERNAME}}"
: "${DISPLAY:=:1}"
: "${DISPLAY_WIDTH:=1600}"
: "${DISPLAY_HEIGHT:=900}"
: "${DISPLAY_DEPTH:=24}"

export HOME="${HOME_DIR}"
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS='@im=fcitx'
export SDL_IM_MODULE=fcitx

if ! pgrep -f "Xvfb ${DISPLAY}" >/dev/null 2>&1; then
  Xvfb "${DISPLAY}" -screen 0 "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}" -ac +extension GLX +render -noreset &
  sleep 2
fi

exec su - "${USERNAME}" -c "export DISPLAY=${DISPLAY}; export GTK_IM_MODULE=fcitx; export QT_IM_MODULE=fcitx; export XMODIFIERS=@im=fcitx; export SDL_IM_MODULE=fcitx; startxfce4"
