#!/usr/bin/env bash
set -euo pipefail

mkdir -p /var/log/ai-workstation

: "${USERNAME:=dev}"
: "${HOME_DIR:=/home/${USERNAME}}"
: "${PASSWORD:=changeme}"
: "${SSH_PASSWORD:=${PASSWORD}}"
: "${VNC_PASSWORD:=${PASSWORD}}"
: "${PUID:=1000}"
: "${PGID:=1000}"
: "${DISPLAY:=:1}"
: "${DISPLAY_WIDTH:=1600}"
: "${DISPLAY_HEIGHT:=900}"
: "${DISPLAY_DEPTH:=24}"
: "${TZ:=America/New_York}"
: "${LANG:=en_US.UTF-8}"
: "${LC_ALL:=${LANG}}"
: "${LANGUAGE:=en_US:en}"
: "${SOCKS5_PROXY_HOST:=host.docker.internal}"
: "${SOCKS5_PROXY_PORT:=1080}"
: "${SOCKS5_PROXY_USERNAME:=}"
: "${SOCKS5_PROXY_PASSWORD:=}"
: "${DIRECT_HOST_IP_MAP:=}"
: "${INTERNAL_DIRECT_CIDRS:=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16}"
: "${DISABLE_LOCAL_DNS:=1}"
: "${ENABLE_IPTABLES:=1}"

export HOME="${HOME_DIR}"
export SHELL=/bin/bash
export TZ
export LANG
export LC_ALL
export LANGUAGE

if [[ -f "/usr/share/zoneinfo/${TZ}" ]]; then
  ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
  echo "${TZ}" >/etc/timezone
fi

PROXY_AUTH_SUFFIX=""
if [[ -n "${SOCKS5_PROXY_USERNAME}" && -n "${SOCKS5_PROXY_PASSWORD}" ]]; then
  PROXY_AUTH_SUFFIX=" ${SOCKS5_PROXY_USERNAME} ${SOCKS5_PROXY_PASSWORD}"
fi

cat >/etc/proxychains4.conf <<EOF
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
EOF
printf 'socks5 %s %s%s\n' "${SOCKS5_PROXY_HOST}" "${SOCKS5_PROXY_PORT}" "${PROXY_AUTH_SUFFIX}" >>/etc/proxychains4.conf

/opt/bin/bootstrap-user.sh

if [[ -n "${DIRECT_HOST_IP_MAP}" ]]; then
  _hosts_tmp="$(mktemp)"
  awk '
    BEGIN { skip=0 }
    /^# BEGIN AI-WORKSTATION DIRECT_HOST_IP_MAP$/ { skip=1; next }
    /^# END AI-WORKSTATION DIRECT_HOST_IP_MAP$/ { skip=0; next }
    skip == 0 { print }
  ' /etc/hosts > "${_hosts_tmp}"
  {
    cat "${_hosts_tmp}"
    echo "# BEGIN AI-WORKSTATION DIRECT_HOST_IP_MAP"
    IFS=',' read -r -a _host_ip_map <<< "${DIRECT_HOST_IP_MAP}"
    for _entry in "${_host_ip_map[@]}"; do
      _entry="${_entry//[[:space:]]/}"
      [[ -z "${_entry}" ]] && continue
      _host="${_entry%%:*}"
      _ip="${_entry#*:}"
      [[ -z "${_host}" || -z "${_ip}" || "${_host}" == "${_ip}" ]] && continue
      printf '%s %s\n' "${_ip}" "${_host}"
    done
    echo "# END AI-WORKSTATION DIRECT_HOST_IP_MAP"
  } > /etc/hosts
  rm -f "${_hosts_tmp}"
fi

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
