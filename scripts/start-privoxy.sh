#!/usr/bin/env bash
set -euo pipefail

: "${SOCKS5_PROXY_HOST:=host.docker.internal}"
: "${SOCKS5_PROXY_PORT:=1080}"
: "${SOCKS5_PROXY_USERNAME:=}"
: "${SOCKS5_PROXY_PASSWORD:=}"
: "${BROWSER_HTTP_PROXY_PORT:=8118}"

FORWARD_RULE="forward-socks5 / ${SOCKS5_PROXY_HOST}:${SOCKS5_PROXY_PORT} ."
if [[ -n "${SOCKS5_PROXY_USERNAME}" && -n "${SOCKS5_PROXY_PASSWORD}" ]]; then
  FORWARD_RULE="forward-socks5 / ${SOCKS5_PROXY_USERNAME}:${SOCKS5_PROXY_PASSWORD}@${SOCKS5_PROXY_HOST}:${SOCKS5_PROXY_PORT} ."
fi

mkdir -p /etc/privoxy

cat >/etc/privoxy/ai-workstation.conf <<EOF
confdir /etc/privoxy
templdir /etc/privoxy/templates
logdir /var/log/ai-workstation
actionsfile match-all.action
actionsfile default.action
actionsfile user.action
filterfile default.filter
logfile privoxy.log
listen-address 127.0.0.1:${BROWSER_HTTP_PROXY_PORT}
toggle 1
enable-remote-toggle 0
enable-edit-actions 0
enable-remote-http-toggle 0
accept-intercepted-requests 0
permit-access 127.0.0.1
forward         localhost/     .
forward         127.*.*.*/     .
forward         10.*.*.*/      .
forward         172.16.*.*/    .
forward         172.17.*.*/    .
forward         172.18.*.*/    .
forward         172.19.*.*/    .
forward         172.20.*.*/    .
forward         172.21.*.*/    .
forward         172.22.*.*/    .
forward         172.23.*.*/    .
forward         172.24.*.*/    .
forward         172.25.*.*/    .
forward         172.26.*.*/    .
forward         172.27.*.*/    .
forward         172.28.*.*/    .
forward         172.29.*.*/    .
forward         172.30.*.*/    .
forward         172.31.*.*/    .
forward         192.168.*.*/   .
${FORWARD_RULE}
EOF

exec /usr/sbin/privoxy --no-daemon /etc/privoxy/ai-workstation.conf
