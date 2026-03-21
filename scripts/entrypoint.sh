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
: "${SOCKS5_PROXY_USERNAME:=}"
: "${SOCKS5_PROXY_PASSWORD:=}"
: "${INTERNAL_DIRECT_CIDRS:=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16}"
: "${DISABLE_LOCAL_DNS:=1}"
: "${ENABLE_IPTABLES:=1}"

export HOME="/home/${USERNAME}"
export SHELL=/bin/bash

PROXY_AUTH_SUFFIX=""
if [[ -n "${SOCKS5_PROXY_USERNAME}" && -n "${SOCKS5_PROXY_PASSWORD}" ]]; then
  PROXY_AUTH_SUFFIX=" ${SOCKS5_PROXY_USERNAME} ${SOCKS5_PROXY_PASSWORD}"
fi

sed \
  -e "s/__SOCKS5_PROXY_HOST__/${SOCKS5_PROXY_HOST//\//\\/}/g" \
  -e "s/__SOCKS5_PROXY_PORT__/${SOCKS5_PROXY_PORT}/g" \
  -e "s/__SOCKS5_PROXY_AUTH_SUFFIX__/${PROXY_AUTH_SUFFIX//\//\\/}/g" \
  /etc/proxychains4.conf > /tmp/proxychains.conf
mv /tmp/proxychains.conf /etc/proxychains4.conf

/opt/bin/bootstrap-user.sh

if [[ "${DISABLE_LOCAL_DNS}" == "1" ]]; then
  cat >/etc/resolv.conf <<'EOF'
# Local DNS disabled; use socks5h / proxychains proxy_dns for external names.
nameserver 127.0.0.254
options timeout:1 attempts:1 ndots:0
EOF
fi

if [[ "${ENABLE_IPTABLES}" == "1" ]]; then
  /opt/bin/apply-egress-lockdown.sh
fi

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
