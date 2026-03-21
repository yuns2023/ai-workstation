#!/usr/bin/env bash
set -euo pipefail

: "${USERNAME:=dev}"
: "${PASSWORD:=changeme}"
: "${SSH_PASSWORD:=${PASSWORD}}"
: "${VNC_PASSWORD:=${PASSWORD}}"
: "${PUID:=1000}"
: "${PGID:=1000}"

if ! getent group "${USERNAME}" >/dev/null 2>&1; then
  groupadd --gid "${PGID}" "${USERNAME}" || groupadd "${USERNAME}"
fi

if ! id -u "${USERNAME}" >/dev/null 2>&1; then
  useradd --uid "${PUID}" --gid "${PGID}" --create-home --shell /bin/bash "${USERNAME}"
fi

echo "${USERNAME}:${SSH_PASSWORD}" | chpasswd
usermod -aG sudo "${USERNAME}"
echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-${USERNAME}
chmod 0440 /etc/sudoers.d/90-${USERNAME}

install -d -m 0700 -o "${USERNAME}" -g "${USERNAME}" "/home/${USERNAME}/.vnc"
install -d -m 0755 -o "${USERNAME}" -g "${USERNAME}" "/home/${USERNAME}/Desktop"
install -d -m 0755 -o "${USERNAME}" -g "${USERNAME}" "/workspace"

su - "${USERNAME}" -c "x11vnc -storepasswd '${VNC_PASSWORD}' '/home/${USERNAME}/.vnc/passwd'" >/dev/null

cat >"/home/${USERNAME}/.bashrc" <<'EOF'
export EDITOR=vim
export VISUAL=vim
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export DISPLAY=${DISPLAY:-:1}
export WORKSPACE=/workspace
export ALL_PROXY=socks5h://${SOCKS5_PROXY_HOST}:${SOCKS5_PROXY_PORT}
export HTTP_PROXY=${ALL_PROXY}
export HTTPS_PROXY=${ALL_PROXY}
export http_proxy=${ALL_PROXY}
export https_proxy=${ALL_PROXY}
export all_proxy=${ALL_PROXY}

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

chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"
