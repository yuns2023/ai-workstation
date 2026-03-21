#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENV_FILE="${PROJECT_DIR}/.env"
if [[ $# -gt 0 && -f "$1" ]]; then
  ENV_FILE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  shift
fi

if [[ $# -eq 0 ]]; then
  echo "usage: $(basename "$0") [env-file] <docker compose args...>" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

: "${EMPLOYEE_ID:?EMPLOYEE_ID must be set in ${ENV_FILE}}"
: "${DATA_ROOT:=./employee-data}"

if [[ "${DATA_ROOT}" = /* ]]; then
  DATA_ROOT_ABS="${DATA_ROOT}"
else
  DATA_ROOT_ABS="$(realpath -m "${PROJECT_DIR}/${DATA_ROOT}")"
fi

export HOME_HOST_DIR="${HOME_HOST_DIR:-${DATA_ROOT_ABS}/${EMPLOYEE_ID}/home}"
export WORKSPACE_HOST_DIR="${WORKSPACE_HOST_DIR:-${DATA_ROOT_ABS}/${EMPLOYEE_ID}/workspace}"
export LOGS_HOST_DIR="${LOGS_HOST_DIR:-${DATA_ROOT_ABS}/${EMPLOYEE_ID}/logs}"
export RUNTIME_ENV_FILE="${ENV_FILE}"

mkdir -p "${HOME_HOST_DIR}" "${WORKSPACE_HOST_DIR}" "${LOGS_HOST_DIR}"

PROJECT_NAME="ai-${EMPLOYEE_ID}"
exec docker compose \
  --project-directory "${PROJECT_DIR}" \
  --env-file "${ENV_FILE}" \
  -p "${PROJECT_NAME}" \
  "$@"
