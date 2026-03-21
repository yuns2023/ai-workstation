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

if [[ ! -x "${BIN_PATH}" ]]; then
  echo "Claude native binary not found: ${BIN_PATH}" >&2
  exit 1
fi

# The native Claude binary rejects socks5h proxy env vars.
# Let proxychains handle egress and keep the runtime env clean.
unset ALL_PROXY HTTP_PROXY HTTPS_PROXY all_proxy http_proxy https_proxy

exec proxychains4 -q "${BIN_PATH}" "$@"
