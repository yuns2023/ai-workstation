#!/usr/bin/env bash
set -euo pipefail

: "${USERNAME:=dev}"
: "${HOME_DIR:=/home/${USERNAME}}"
: "${PASSWORD:=changeme}"
: "${SSH_PASSWORD:=${PASSWORD}}"
: "${VNC_PASSWORD:=${PASSWORD}}"
: "${PUID:=1000}"
: "${PGID:=1000}"
: "${DISPLAY:=:1}"
: "${TZ:=America/New_York}"
: "${LANG:=en_US.UTF-8}"
: "${LC_ALL:=${LANG}}"
: "${LANGUAGE:=en_US:en}"
: "${INTERNAL_DIRECT_CIDRS:=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16}"
: "${DIRECT_HOSTS:=}"
: "${DIRECT_IPS:=}"
: "${SOCKS5_PROXY_HOST:=host.docker.internal}"
: "${SOCKS5_PROXY_PORT:=1080}"
: "${SOCKS5_PROXY_USERNAME:=}"
: "${SOCKS5_PROXY_PASSWORD:=}"
: "${BROWSER_HTTP_PROXY_PORT:=8118}"

if [[ "${HOME_DIR}" != /* ]]; then
  echo "HOME_DIR must be an absolute path: ${HOME_DIR}" >&2
  exit 1
fi

HOME_PARENT="$(dirname "${HOME_DIR}")"
install -d -m 0755 "${HOME_PARENT}"

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
  USERADD_ARGS=(--gid "${GROUP_NAME}" --home-dir "${HOME_DIR}" --create-home --shell /bin/bash)
  if ! getent passwd "${PUID}" >/dev/null 2>&1; then
    USERADD_ARGS+=(--uid "${PUID}")
  fi
  useradd "${USERADD_ARGS[@]}" "${USERNAME}"
fi

CURRENT_HOME="$(getent passwd "${USERNAME}" | cut -d: -f6)"
if [[ "${CURRENT_HOME}" != "${HOME_DIR}" ]]; then
  usermod --home "${HOME_DIR}" "${USERNAME}"
fi

usermod --gid "${GROUP_NAME}" "${USERNAME}"
echo "${USERNAME}:${SSH_PASSWORD}" | chpasswd
usermod -aG sudo "${USERNAME}"
echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-${USERNAME}
chmod 0440 /etc/sudoers.d/90-${USERNAME}

install -d -m 0755 -o "${USERNAME}" -g "${GROUP_NAME}" "${HOME_DIR}"
install -d -m 0700 -o "${USERNAME}" -g "${GROUP_NAME}" "${HOME_DIR}/.vnc"
install -d -m 0755 -o "${USERNAME}" -g "${GROUP_NAME}" "${HOME_DIR}/Desktop"
install -d -m 0755 -o "${USERNAME}" -g "${GROUP_NAME}" "${HOME_DIR}/.config"
install -d -m 0755 -o "${USERNAME}" -g "${GROUP_NAME}" "${HOME_DIR}/.config/autostart"
install -d -m 0755 -o "${USERNAME}" -g "${GROUP_NAME}" "${HOME_DIR}/.config/fcitx5"
install -d -m 0755 -o "${USERNAME}" -g "${GROUP_NAME}" "/workspace"

VNC_PASSWORD_SHELL="$(printf '%q' "${VNC_PASSWORD}")"
VNC_PASSWD_FILE_SHELL="$(printf '%q' "${HOME_DIR}/.vnc/passwd")"
su - "${USERNAME}" -c "x11vnc -storepasswd ${VNC_PASSWORD_SHELL} ${VNC_PASSWD_FILE_SHELL}" >/dev/null

DISPLAY_SHELL="$(printf '%q' "${DISPLAY}")"
WORKSPACE_SHELL="$(printf '%q' "/workspace")"
ALL_PROXY_SHELL="$(printf '%q' "${ALL_PROXY_URL}")"
NO_PROXY_VALUE="127.0.0.1,localhost,${INTERNAL_DIRECT_CIDRS}"
if [[ -n "${DIRECT_HOSTS}" ]]; then
  NO_PROXY_VALUE="${NO_PROXY_VALUE},${DIRECT_HOSTS}"
fi
if [[ -n "${DIRECT_IPS}" ]]; then
  NO_PROXY_VALUE="${NO_PROXY_VALUE},${DIRECT_IPS}"
fi
NO_PROXY_SHELL="$(printf '%q' "${NO_PROXY_VALUE}")"
DIRECT_HOSTS_SHELL="$(printf '%q' "${DIRECT_HOSTS}")"
DIRECT_IPS_SHELL="$(printf '%q' "${DIRECT_IPS}")"
TZ_SHELL="$(printf '%q' "${TZ}")"
LANG_SHELL="$(printf '%q' "${LANG}")"
LC_ALL_SHELL="$(printf '%q' "${LC_ALL}")"
LANGUAGE_SHELL="$(printf '%q' "${LANGUAGE}")"

cat >"${HOME_DIR}/.bashrc" <<EOF
export EDITOR=vim
export VISUAL=vim
export TZ=${TZ_SHELL}
export LANG=${LANG_SHELL}
export LC_ALL=${LC_ALL_SHELL}
export LANGUAGE=${LANGUAGE_SHELL}
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx
if [[ -z "\${TERM:-}" || "\${TERM}" == "dumb" ]]; then
  export TERM=xterm-256color
elif ! infocmp "\${TERM}" >/dev/null 2>&1; then
  export TERM=xterm-256color
fi
export DISPLAY=${DISPLAY_SHELL}
export WORKSPACE=${WORKSPACE_SHELL}
export ALL_PROXY=${ALL_PROXY_SHELL}
export DIRECT_HOSTS=${DIRECT_HOSTS_SHELL}
export DIRECT_IPS=${DIRECT_IPS_SHELL}
export NO_PROXY=${NO_PROXY_SHELL}
export no_proxy=\${NO_PROXY}
export HTTP_PROXY=\${ALL_PROXY}
export HTTPS_PROXY=\${ALL_PROXY}
export http_proxy=\${ALL_PROXY}
export https_proxy=\${ALL_PROXY}
export all_proxy=\${ALL_PROXY}

alias codex='proxy-codex'
alias claude='proxy-claude'
alias browser='proxy-browser'
alias pgit='proxy-shell git'
alias pcurl='proxy-shell curl'
alias pwget='proxy-shell wget'
cd /workspace
EOF

if [[ ! -f "${HOME_DIR}/.config/fcitx5/profile" ]]; then
cat >"${HOME_DIR}/.config/fcitx5/profile" <<'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=keyboard-us

[Groups/0/Items/0]
Name=wbx
Layout=

[Groups/0/Items/1]
Name=wbpy
Layout=

[Groups/0/Items/2]
Name=keyboard-us
Layout=

[GroupOrder]
0=Default
EOF
fi

if [[ ! -f "${HOME_DIR}/.config/fcitx5/config" ]]; then
cat >"${HOME_DIR}/.config/fcitx5/config" <<'EOF'
[Hotkey]
EnumerateWithTriggerKeys=True
EnumerateForwardKeys=
EnumerateBackwardKeys=
EnumerateSkipFirst=False

[Hotkey/TriggerKeys]
0=Control+space
1=Zenkaku_Hankaku
2=Hangul

[Hotkey/AltTriggerKeys]
0=Shift_L

[Behavior]
ActiveByDefault=False
ShareInputState=No
PreeditEnabledByDefault=True
ShowInputMethodInformation=True
showInputMethodInformationWhenFocusIn=False
CompactInputMethodInformation=True
ShowFirstInputMethodInformation=True
DefaultPageSize=5
OverrideXkbOption=False
CustomXkbOption=
EnabledAddons=
DisabledAddons=
PreloadInputMethod=True
AllowInputMethodForPassword=False
ShowPreeditForPassword=False
AutoSavePeriod=30
EOF
fi

if [[ -f /usr/share/applications/org.fcitx.Fcitx5.desktop && ! -f "${HOME_DIR}/.config/autostart/org.fcitx.Fcitx5.desktop" ]]; then
  install -m 0644 /usr/share/applications/org.fcitx.Fcitx5.desktop "${HOME_DIR}/.config/autostart/org.fcitx.Fcitx5.desktop"
fi

cat >"${HOME_DIR}/Desktop/README.txt" <<EOF
SSH login user: ${USERNAME}
Web VNC URL: http://<host>:\${WEB_VNC_PORT:-6080}/
Workspace: /workspace
Proxy: socks5h://${SOCKS5_PROXY_HOST}:${SOCKS5_PROXY_PORT}
EOF

cat >"${HOME_DIR}/Desktop/Chromium (Proxy).desktop" <<EOF
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

chmod 0755 "${HOME_DIR}/Desktop/Chromium (Proxy).desktop"

chown -R "${USERNAME}:${GROUP_NAME}" "${HOME_DIR}"
