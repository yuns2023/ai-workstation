#!/usr/bin/env bash
set -euo pipefail

: "${SOCKS5_PROXY_HOST:=host.docker.internal}"
: "${SOCKS5_PROXY_PORT:=1080}"

PROXY_IP="$(getent ahostsv4 "${SOCKS5_PROXY_HOST}" | awk 'NR==1 {print $1}')"
if [[ -z "${PROXY_IP}" ]]; then
  echo "failed to resolve SOCKS5 proxy host: ${SOCKS5_PROXY_HOST}" >&2
  exit 1
fi

iptables -F OUTPUT
iptables -P OUTPUT DROP
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -d "${PROXY_IP}" -p tcp --dport "${SOCKS5_PROXY_PORT}" -j ACCEPT
iptables -A OUTPUT -d 127.0.0.11 -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -d 127.0.0.11 -p tcp --dport 53 -j ACCEPT
