#!/usr/bin/env bash
set -euo pipefail

# Claude Code's rich TUI can render as a blank screen on some SSH clients.
# Prefer conservative terminal settings and disable fragile UI features by default.
if [[ -z "${TERM:-}" || "${TERM}" == "dumb" ]]; then
  export TERM=xterm-256color
elif ! infocmp "${TERM}" >/dev/null 2>&1; then
  export TERM=xterm-256color
fi

: "${COLORTERM:=truecolor}"
: "${FORCE_COLOR:=3}"
: "${CLAUDE_CODE_DISABLE_TERMINAL_TITLE:=1}"
: "${CLAUDE_CODE_DISABLE_VIRTUAL_SCROLL:=1}"
: "${CLAUDE_CODE_ACCESSIBILITY:=1}"

export COLORTERM
export FORCE_COLOR
export CLAUDE_CODE_DISABLE_TERMINAL_TITLE
export CLAUDE_CODE_DISABLE_VIRTUAL_SCROLL
export CLAUDE_CODE_ACCESSIBILITY

if [[ -t 0 && -t 1 ]]; then
  if read -r _rows _cols < <(stty size 2>/dev/null); then
    if [[ -n "${_rows}" && -n "${_cols}" ]]; then
      : "${LINES:=${_rows}}"
      : "${COLUMNS:=${_cols}}"
      export LINES
      export COLUMNS
    fi
  fi
fi

BIN_PATH="${CLAUDE_NATIVE_BIN:-/usr/local/bin/claude-native}"
: "${BROWSER_HTTP_PROXY_PORT:=8118}"

if [[ ! -x "${BIN_PATH}" ]]; then
  echo "Claude native binary not found: ${BIN_PATH}" >&2
  exit 1
fi

# Claude Code officially supports HTTP(S) proxies, not SOCKS proxies.
# Route it through the local Privoxy bridge, which forwards to the upstream SOCKS5 proxy.
LOCAL_HTTP_PROXY="http://127.0.0.1:${BROWSER_HTTP_PROXY_PORT}"
export HTTP_PROXY="${LOCAL_HTTP_PROXY}"
export HTTPS_PROXY="${LOCAL_HTTP_PROXY}"
export http_proxy="${LOCAL_HTTP_PROXY}"
export https_proxy="${LOCAL_HTTP_PROXY}"
export NO_PROXY="127.0.0.1,localhost"
export no_proxy="${NO_PROXY}"
unset ALL_PROXY all_proxy

exec "${BIN_PATH}" "$@"
