#!/usr/bin/env bash
set -euo pipefail

BIN_PATH="$(node -e "const path=require('path'); const pkg=require('/usr/local/lib/node_modules/@openai/codex/package.json'); const bin=typeof pkg.bin==='string'?pkg.bin:pkg.bin.codex||Object.values(pkg.bin)[0]; process.stdout.write(path.resolve('/usr/local/lib/node_modules/@openai/codex', bin));")"

exec proxychains4 -q node "${BIN_PATH}" "$@"
