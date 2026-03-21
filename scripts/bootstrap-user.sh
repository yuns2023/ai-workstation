#!/usr/bin/env bash
set -euo pipefail

: "${USERNAME:=dev}"
: "${PASSWORD:=changeme}"
: "${SSH_PASSWORD:=${PASSWORD}}"
: "${VNC_PASSWORD:=${PASSWORD}}"
: "${PUID:=1000}"
: "${PGID:=1000}"
: "${DISPLAY:=:1}"
: "${SOCKS5_PROXY_HOST:=host.docker.internal}"
: "${SOCKS5_PROXY_PORT:=1080}"
: "${SOCKS5_PROXY_USERNAME:=}"
: "${SOCKS5_PROXY_PASSWORD:=}"
: "${BROWSER_HTTP_PROXY_PORT:=8118}"

ALL_PROXY_URL="socks5h://${SOCKS5_PROXY_HOST}:${SOCKS5_PROXY_PORT}"
if [[ -n "${SOCKS5_PROXY_USERNAME}" && -n "${SOCKS5_PROXY_PASSWORD}" ]]; then
  ALL_PROXY_URL="socks5h://${SOCKS5_PROXY_USERNAME}:${SOCKS5_PROXY_PASSWORD}@${SOCKS5_PROXY_HOST}:${SOCKS5_PROXY_PORT}"
fi

GROUP_NAME="${USERNAME}"
if getent group "${USERNAME}" >/dev/null 2>&1; then
  GROUP_NAME="${USERNAME}"
elif getent group "${PGID}" >/dev/null 2>&1; then
  GROUP_NAME="$(getent group "${PGID}" | cut -d: -f1)"
else
  groupadd --gid "${PGID}" "${USERNAME}"
fi

if ! id -u "${USERNAME}" >/dev/null 2>&1; then
  USERADD_ARGS=(--gid "${GROUP_NAME}" --create-home --shell /bin/bash)
  if ! getent passwd "${PUID}" >/dev/null 2>&1; then
    USERADD_ARGS+=(--uid "${PUID}")
  fi
  useradd "${USERADD_ARGS[@]}" "${USERNAME}"
fi

usermod --gid "${GROUP_NAME}" "${USERNAME}"
echo "${USERNAME}:${SSH_PASSWORD}" | chpasswd
usermod -aG sudo "${USERNAME}"
echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-${USERNAME}
chmod 0440 /etc/sudoers.d/90-${USERNAME}

install -d -m 0700 -o "${USERNAME}" -g "${GROUP_NAME}" "/home/${USERNAME}/.vnc"
install -d -m 0755 -o "${USERNAME}" -g "${GROUP_NAME}" "/home/${USERNAME}/Desktop"
install -d -m 0755 -o "${USERNAME}" -g "${GROUP_NAME}" "/workspace"

VNC_PASSWORD_SHELL="$(printf '%q' "${VNC_PASSWORD}")"
VNC_PASSWD_FILE_SHELL="$(printf '%q' "/home/${USERNAME}/.vnc/passwd")"
su - "${USERNAME}" -c "x11vnc -storepasswd ${VNC_PASSWORD_SHELL} ${VNC_PASSWD_FILE_SHELL}" >/dev/null

DISPLAY_SHELL="$(printf '%q' "${DISPLAY}")"
WORKSPACE_SHELL="$(printf '%q' "/workspace")"
ALL_PROXY_SHELL="$(printf '%q' "${ALL_PROXY_URL}")"

cat >"/home/${USERNAME}/.bashrc" <<EOF
export EDITOR=vim
export VISUAL=vim
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
if [[ -z "\${TERM:-}" || "\${TERM}" == "dumb" ]]; then
  export TERM=xterm-256color
fi
export DISPLAY=${DISPLAY_SHELL}
export WORKSPACE=${WORKSPACE_SHELL}
export ALL_PROXY=${ALL_PROXY_SHELL}
export HTTP_PROXY=\${ALL_PROXY}
export HTTPS_PROXY=\${ALL_PROXY}
export http_proxy=\${ALL_PROXY}
export https_proxy=\${ALL_PROXY}
export all_proxy=\${ALL_PROXY}

alias codex='proxy-codex'
alias claude='proxy-claude'
alias browser='proxy-browser'
alias git='proxychains4 -q git'
alias curl='proxychains4 -q curl'
alias wget='proxychains4 -q wget'
cd /workspace
EOF

cat >"/home/${USERNAME}/Desktop/README.txt" <<EOF
SSH login user: ${USERNAME}
Web VNC URL: http://<host>:\${WEB_VNC_PORT:-6080}/
Workspace: /workspace
Proxy: socks5h://${SOCKS5_PROXY_HOST}:${SOCKS5_PROXY_PORT}
EOF

cat >"/home/${USERNAME}/Desktop/Chromium (Proxy).desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Chromium (Proxy)
Comment=Chromium routed through local Privoxy to authenticated SOCKS5
Exec=proxy-browser
Icon=chromium
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF

chmod 0755 "/home/${USERNAME}/Desktop/Chromium (Proxy).desktop"

chown -R "${USERNAME}:${GROUP_NAME}" "/home/${USERNAME}"
