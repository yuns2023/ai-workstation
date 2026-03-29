#!/usr/bin/env bash
set -euo pipefail

: "${USERNAME:=dev}"
: "${HOME_DIR:=/home/${USERNAME}}"
: "${DISPLAY:=:1}"
: "${VNC_SERVER_IMPL:=auto}"
: "${REALVNC_LICENSE_KEY:=}"
: "${REALVNC_AUTHENTICATION:=VncAuth}"
: "${REALVNC_ENCRYPTION:=AlwaysOn}"
: "${REALVNC_DISABLE_TRAY_ICON:=1}"
: "${VNC_PASSWORD:=changeme}"

VNC_PASSWD_FILE_SHELL="$(printf '%q' "${HOME_DIR}/.vnc/passwd")"

case "${VNC_SERVER_IMPL}" in
  auto)
    if [[ -n "${REALVNC_LICENSE_KEY}" ]]; then
      VNC_SERVER_IMPL="realvnc"
    else
      VNC_SERVER_IMPL="x11vnc"
    fi
    ;;
  realvnc|x11vnc)
    ;;
  *)
    echo "Unsupported VNC_SERVER_IMPL: ${VNC_SERVER_IMPL}" >&2
    exit 1
    ;;
esac

if [[ "${VNC_SERVER_IMPL}" == "realvnc" ]]; then
  if [[ -z "${REALVNC_LICENSE_KEY}" ]]; then
    echo "REALVNC_LICENSE_KEY is required when VNC_SERVER_IMPL=realvnc" >&2
    exit 1
  fi

  if command -v vnclicense >/dev/null 2>&1; then
    key_prefix="${REALVNC_LICENSE_KEY%%-*}-"
    if ! vnclicense -list 2>/dev/null | grep -Fq "${key_prefix}"; then
      vnclicense -reload -add "${REALVNC_LICENSE_KEY}"
    fi
  fi

  printf '%s\n%s\n' "${VNC_PASSWORD}" "${VNC_PASSWORD}" | su - "${USERNAME}" -c "vncpasswd -user"
  su - "${USERNAME}" -c "vncserver-x11 -stop" >/dev/null 2>&1 || true
  rm -f /tmp/realvnc-user.log

  su - "${USERNAME}" -c "export DISPLAY=${DISPLAY}; nohup vncserver-x11 -display ${DISPLAY} -Authentication ${REALVNC_AUTHENTICATION} -Encryption ${REALVNC_ENCRYPTION} -DisableTrayIcon=${REALVNC_DISABLE_TRAY_ICON} >/tmp/realvnc-user.log 2>&1 &"
  sleep 3

  if ! pgrep -f '/usr/bin/vncserver-x11-core' >/dev/null 2>&1; then
    sed -n '1,200p' /tmp/realvnc-user.log >&2 || true
    sed -n '1,200p' "${HOME_DIR}/.vnc/vncserver-x11.log" >&2 || true
    exit 1
  fi

  core_pid="$(pgrep -f '/usr/bin/vncserver-x11-core' | head -n 1)"
  touch /tmp/realvnc-user.log "${HOME_DIR}/.vnc/vncserver-x11.log"
  tail -n +1 -F /tmp/realvnc-user.log "${HOME_DIR}/.vnc/vncserver-x11.log" &
  tail_pid=$!
  while kill -0 "${core_pid}" >/dev/null 2>&1; do
    sleep 2
  done
  kill "${tail_pid}" >/dev/null 2>&1 || true
  exit 1
fi

exec su - "${USERNAME}" -c "x11vnc -display ${DISPLAY} -forever -shared -repeat -xkb -noshm -noxdamage -rfbauth ${VNC_PASSWD_FILE_SHELL} -rfbport 5900"
