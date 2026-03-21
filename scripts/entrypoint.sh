#!/usr/bin/env bash
set -euo pipefail

mkdir -p /var/log/ai-workstation

: "${USERNAME:=dev}"
: "${PASSWORD:=changeme}"
: "${SSH_PASSWORD:=${PASSWORD}}"
: "${VNC_PASSWORD:=${PASSWORD}}"
: "${PUID:=1000}"
: "${PGID:=1000}"
: "${DISPLAY:=:1}"
: "${DISPLAY_WIDTH:=1600}"
: "${DISPLAY_HEIGHT:=900}"
: "${DISPLAY_DEPTH:=24}"
: "${SOCKS5_PROXY_HOST:=host.docker.internal}"
: "${SOCKS5_PROXY_PORT:=1080}"
: "${ENABLE_IPTABLES:=1}"

export HOME="/home/${USERNAME}"
export SHELL=/bin/bash

sed \
  -e "s/__SOCKS5_PROXY_HOST__/${SOCKS5_PROXY_HOST//\//\\/}/g" \
  -e "s/__SOCKS5_PROXY_PORT__/${SOCKS5_PROXY_PORT}/g" \
  /etc/proxychains4.conf > /tmp/proxychains.conf
mv /tmp/proxychains.conf /etc/proxychains4.conf

/opt/bin/bootstrap-user.sh

if [[ "${ENABLE_IPTABLES}" == "1" ]]; then
  /opt/bin/apply-egress-lockdown.sh
fi

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
