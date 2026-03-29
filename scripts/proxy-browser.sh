#!/usr/bin/env bash
set -euo pipefail

: "${BROWSER_HTTP_PROXY_PORT:=8118}"
: "${BROWSER_LANG:=en-US}"
: "${DIRECT_HOSTS:=}"
: "${DIRECT_IPS:=}"

CHROMIUM_BIN="$(command -v chromium)"
PROFILE_DIR="${HOME}/.config/chromium-proxy"
BYPASS_LIST="<local>;localhost;127.0.0.1;10.0.0.0/8;172.16.0.0/12;192.168.0.0/16"

mkdir -p "${PROFILE_DIR}"

if [[ -n "${DIRECT_HOSTS}" ]]; then
  IFS=',' read -r -a _direct_hosts <<< "${DIRECT_HOSTS}"
  for _host in "${_direct_hosts[@]}"; do
    _host="${_host//[[:space:]]/}"
    [[ -z "${_host}" ]] && continue
    BYPASS_LIST="${BYPASS_LIST};${_host}"
  done
fi

if [[ -n "${DIRECT_IPS}" ]]; then
  IFS=',' read -r -a _direct_ips <<< "${DIRECT_IPS}"
  for _ip in "${_direct_ips[@]}"; do
    _ip="${_ip//[[:space:]]/}"
    [[ -z "${_ip}" ]] && continue
    BYPASS_LIST="${BYPASS_LIST};${_ip}"
  done
fi

exec "${CHROMIUM_BIN}" \
  --user-data-dir="${PROFILE_DIR}" \
  --lang="${BROWSER_LANG}" \
  --proxy-server="http://127.0.0.1:${BROWSER_HTTP_PROXY_PORT}" \
  --proxy-bypass-list="${BYPASS_LIST}" \
  --disable-background-networking \
  --disable-component-update \
  --disable-domain-reliability \
  --disable-features=DialMediaRouteProvider,MediaRouter,DnsOverHttps,UseDnsHttpsSvcb \
  --disable-sync \
  --no-default-browser-check \
  --no-first-run \
  --password-store=basic \
  --disable-dev-shm-usage \
  --no-sandbox \
  "$@"
