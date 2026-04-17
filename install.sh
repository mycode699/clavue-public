#!/usr/bin/env bash
set -euo pipefail

PACKAGE="${CLAVUE_PACKAGE:-clavue}"
VERSION_INPUT="${1:-${CLAVUE_VERSION:-latest}}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

check_node() {
  need_cmd node

  local node_major
  node_major="$(node -p "process.versions.node.split('.')[0]")"
  if [[ -z "$node_major" || "$node_major" -lt 18 ]]; then
    printf 'clavue requires Node.js 18 or newer. Found: %s\n' "$(node -v)" >&2
    exit 1
  fi
}

resolve_version() {
  if [[ "$VERSION_INPUT" != "latest" ]]; then
    printf '%s' "${VERSION_INPUT#v}"
    return 0
  fi

  npm view "$PACKAGE" version
}

main() {
  need_cmd npm
  check_node

  local version
  version="$(resolve_version)"
  if [[ -z "$version" ]]; then
    printf 'Unable to determine the latest %s version from npm.\n' "$PACKAGE" >&2
    exit 1
  fi

  printf 'Installing %s@%s from npm...\n' "$PACKAGE" "$version"
  npm install -g "${PACKAGE}@${version}"

  printf 'Installed %s@%s\n' "$PACKAGE" "$version"
  printf 'Available commands after npm install: clavue\n'
  printf 'Running native launcher setup so the clavue command is configured...\n'

  clavue install --force
  clavue --version || true
}

main "$@"
