#!/usr/bin/env bash
set -euo pipefail

: "${SOCKS5_PROXY_HOST:=host.docker.internal}"
: "${SOCKS5_PROXY_PORT:=1080}"
: "${INTERNAL_DIRECT_CIDRS:=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16}"
: "${DIRECT_IPS:=}"

if [[ "${SOCKS5_PROXY_HOST}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  PROXY_IP="${SOCKS5_PROXY_HOST}"
else
  echo "SOCKS5_PROXY_HOST must be an IPv4 address when local DNS is disabled: ${SOCKS5_PROXY_HOST}" >&2
  exit 1
fi

iptables -F OUTPUT
iptables -P OUTPUT DROP
iptables -A OUTPUT -p udp --dport 53 -j REJECT
iptables -A OUTPUT -p tcp --dport 53 -j REJECT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

ip6tables -F OUTPUT
ip6tables -P OUTPUT DROP
ip6tables -A OUTPUT -o lo -j ACCEPT
ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

IFS=',' read -r -a CIDR_LIST <<< "${INTERNAL_DIRECT_CIDRS}"
for cidr in "${CIDR_LIST[@]}"; do
  cidr="${cidr//[[:space:]]/}"
  [[ -z "${cidr}" ]] && continue
  iptables -A OUTPUT -d "${cidr}" -j ACCEPT
done

IFS=',' read -r -a DIRECT_IP_LIST <<< "${DIRECT_IPS}"
for ip in "${DIRECT_IP_LIST[@]}"; do
  ip="${ip//[[:space:]]/}"
  [[ -z "${ip}" ]] && continue
  iptables -A OUTPUT -d "${ip}" -j ACCEPT
done

iptables -A OUTPUT -d "${PROXY_IP}" -p tcp --dport "${SOCKS5_PROXY_PORT}" -j ACCEPT
