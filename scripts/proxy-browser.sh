#!/usr/bin/env bash
set -euo pipefail

: "${BROWSER_HTTP_PROXY_PORT:=8118}"
: "${BROWSER_LANG:=en-US}"

CHROMIUM_BIN="$(command -v chromium)"
PROFILE_DIR="${HOME}/.config/chromium-proxy"

mkdir -p "${PROFILE_DIR}"

exec "${CHROMIUM_BIN}" \
  --user-data-dir="${PROFILE_DIR}" \
  --lang="${BROWSER_LANG}" \
  --proxy-server="http://127.0.0.1:${BROWSER_HTTP_PROXY_PORT}" \
  --host-resolver-rules="MAP * ~NOTFOUND , EXCLUDE localhost , EXCLUDE 127.0.0.1" \
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
