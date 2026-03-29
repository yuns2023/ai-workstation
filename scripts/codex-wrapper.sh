#!/usr/bin/env bash
set -euo pipefail

: "${DIRECT_HOSTS:=}"
: "${DIRECT_IPS:=}"

BIN_PATH="$(node -e "const path=require('path'); const pkg=require('/usr/local/lib/node_modules/@openai/codex/package.json'); const bin=typeof pkg.bin==='string'?pkg.bin:pkg.bin.codex||Object.values(pkg.bin)[0]; process.stdout.write(path.resolve('/usr/local/lib/node_modules/@openai/codex', bin));")"

BASE_URL=""
if [[ -f "${HOME}/.codex/config.toml" ]]; then
  BASE_URL="$(sed -n 's/^base_url = "\(.*\)"/\1/p' "${HOME}/.codex/config.toml" | head -n 1)"
fi

TARGET_HOST=""
if [[ -n "${BASE_URL}" ]]; then
  TARGET_HOST="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.urlparse(sys.argv[1]).hostname or "")' "${BASE_URL}")"
fi

should_go_direct() {
  local host="$1"
  local item
  [[ -z "${host}" ]] && return 1
  IFS=',' read -r -a _hosts <<< "${DIRECT_HOSTS}"
  for item in "${_hosts[@]}"; do
    item="${item//[[:space:]]/}"
    [[ -z "${item}" ]] && continue
    [[ "${host}" == "${item}" ]] && return 0
  done
  IFS=',' read -r -a _ips <<< "${DIRECT_IPS}"
  for item in "${_ips[@]}"; do
    item="${item//[[:space:]]/}"
    [[ -z "${item}" ]] && continue
    [[ "${host}" == "${item}" ]] && return 0
  done
  return 1
}

if should_go_direct "${TARGET_HOST}"; then
  unset ALL_PROXY HTTP_PROXY HTTPS_PROXY NO_PROXY
  unset all_proxy http_proxy https_proxy no_proxy
  exec node "${BIN_PATH}" "$@"
fi

exec proxy-shell node "${BIN_PATH}" "$@"
