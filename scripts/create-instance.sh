#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create-instance.sh <name> [options]

Options:
  --dir <path>         Instance directory. Default: ../ai-workstation-instances/<name>
  --state-root <path>  Persistent data root. Default: ../ai-workstation-state/<name>
  --ssh-port <port>    SSH port. Default: next free port from 2222
  --web-port <port>    Web VNC port. Default: next free port from 6080
  -h, --help           Show this help

This creates a minimal instance directory containing only:
  - docker-compose.yml
  - .env

Persistent state is stored outside the source repo by default.
EOF
}

require_arg() {
  local flag="$1"
  local value="${2:-}"
  if [[ -z "${value}" ]]; then
    echo "Missing value for ${flag}" >&2
    exit 1
  fi
}

port_in_use() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltnH "( sport = :${port} )" 2>/dev/null | grep -q .
    return
  fi
  if command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${port}$"
    return
  fi
  return 1
}

port_reserved_in_envs() {
  local key="$1"
  local port="$2"
  local env_file

  if [[ ! -d "${INSTANCES_ROOT}" ]]; then
    return 1
  fi

  while IFS= read -r env_file; do
    [[ "${env_file}" == "${INSTANCE_DIR}/.env" ]] && continue
    if grep -Eq "^${key}=${port}$" "${env_file}"; then
      return 0
    fi
  done < <(find "${INSTANCES_ROOT}" -mindepth 2 -maxdepth 2 -name .env -type f 2>/dev/null | sort)

  return 1
}

next_free_port() {
  local key="$1"
  local start="$2"
  local port="${start}"

  while true; do
    if port_in_use "${port}" || port_reserved_in_envs "${key}" "${port}"; then
      port="$((port + 1))"
      continue
    fi
    printf '%s\n' "${port}"
    return 0
  done
}

set_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"

  if grep -q "^${key}=" "${file}"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "${file}"
  else
    printf '%s=%s\n' "${key}" "${value}" >>"${file}"
  fi
}

NAME="${1:-}"
if [[ -z "${NAME}" ]]; then
  usage
  exit 1
fi
shift

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
TEMPLATE_DIR="${REPO_ROOT}/deploy-template"
DEFAULT_PARENT="$(cd "${REPO_ROOT}/.." && pwd -P)"
INSTANCES_ROOT="${AI_WORKSTATION_INSTANCES_ROOT:-${DEFAULT_PARENT}/ai-workstation-instances}"
STATE_ROOT_BASE="${AI_WORKSTATION_STATE_ROOT:-${DEFAULT_PARENT}/ai-workstation-state}"

INSTANCE_DIR="${INSTANCES_ROOT}/${NAME}"
STATE_ROOT="${STATE_ROOT_BASE}/${NAME}"
SSH_PORT=""
WEB_VNC_PORT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      require_arg "$1" "${2:-}"
      INSTANCE_DIR="$2"
      shift 2
      ;;
    --state-root)
      require_arg "$1" "${2:-}"
      STATE_ROOT="$2"
      shift 2
      ;;
    --ssh-port)
      require_arg "$1" "${2:-}"
      SSH_PORT="$2"
      shift 2
      ;;
    --web-port)
      require_arg "$1" "${2:-}"
      WEB_VNC_PORT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "${TEMPLATE_DIR}/docker-compose.yml" || ! -f "${TEMPLATE_DIR}/.env.example" ]]; then
  echo "Deploy template is incomplete: ${TEMPLATE_DIR}" >&2
  exit 1
fi

if [[ -e "${INSTANCE_DIR}/docker-compose.yml" || -e "${INSTANCE_DIR}/.env" ]]; then
  echo "Instance already exists: ${INSTANCE_DIR}" >&2
  exit 1
fi

mkdir -p "${INSTANCE_DIR}" "${STATE_ROOT}/home" "${STATE_ROOT}/workspace" "${STATE_ROOT}/logs"

cp "${TEMPLATE_DIR}/docker-compose.yml" "${INSTANCE_DIR}/docker-compose.yml"
cp "${TEMPLATE_DIR}/.env.example" "${INSTANCE_DIR}/.env"

if [[ -z "${SSH_PORT}" ]]; then
  SSH_PORT="$(next_free_port SSH_PORT 2222)"
fi

if [[ -z "${WEB_VNC_PORT}" ]]; then
  WEB_VNC_PORT="$(next_free_port WEB_VNC_PORT 6080)"
fi

set_env_value "${INSTANCE_DIR}/.env" COMPOSE_PROJECT_NAME "ai-${NAME}"
set_env_value "${INSTANCE_DIR}/.env" HOME_HOST_DIR "${STATE_ROOT}/home"
set_env_value "${INSTANCE_DIR}/.env" WORKSPACE_HOST_DIR "${STATE_ROOT}/workspace"
set_env_value "${INSTANCE_DIR}/.env" LOGS_HOST_DIR "${STATE_ROOT}/logs"
set_env_value "${INSTANCE_DIR}/.env" SSH_PORT "${SSH_PORT}"
set_env_value "${INSTANCE_DIR}/.env" WEB_VNC_PORT "${WEB_VNC_PORT}"

cat <<EOF
Created instance: ${NAME}
Instance dir: ${INSTANCE_DIR}
State root: ${STATE_ROOT}
SSH port: ${SSH_PORT}
Web VNC port: ${WEB_VNC_PORT}

Next steps:
  1. Edit ${INSTANCE_DIR}/.env
  2. Start it with:
     cd ${INSTANCE_DIR}
     docker compose up -d
EOF
