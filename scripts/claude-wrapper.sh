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

BIN_PATH="$(node -e "const path=require('path'); const pkg=require('/usr/local/lib/node_modules/@anthropic-ai/claude-code/package.json'); const bin=typeof pkg.bin==='string'?pkg.bin:pkg.bin.claude||Object.values(pkg.bin)[0]; process.stdout.write(path.resolve('/usr/local/lib/node_modules/@anthropic-ai/claude-code', bin));")"

exec proxychains4 -q node "${BIN_PATH}" "$@"
