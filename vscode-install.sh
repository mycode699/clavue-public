#!/usr/bin/env bash
set -euo pipefail

# Official installer & upgrader for Clavue Code (clavue.clavue-code).
# Compatible with macOS bash 3.2+ and Linux bash.
#
# Examples:
#   curl -fsSL https://www.clavue.com/vscode/install.sh | bash
#   curl -fsSL https://www.clavue.com/vscode/install.sh | bash -s -- --target imux
#   bash scripts/install-vsix.sh --local --target imux
#   bash scripts/install-vsix.sh --version 0.1.0 --target vscode

FEED_URL="${CLAVUE_VSCODE_FEED_URL:-https://www.clavue.com/vscode/feed.json}"
FALLBACK_FEED_URL="https://raw.githubusercontent.com/mycode699/clavue-public/main/vscode-feed.json"
SCRIPT_SRC="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_SRC" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SRC")" && pwd)"
  ROOT_DIR="$(cd "${SCRIPT_DIR}/.." 2>/dev/null && pwd || pwd)"
else
  ROOT_DIR="$(pwd)"
fi

VSIX_PATH=""
USE_LOCAL=0
TARGET="auto"
REQUESTED_VERSION=""
CHANNEL="stable"
FORCE_DOWNGRADE=0

usage() {
  cat <<'EOF'
Usage: install-vsix.sh [options]

Options:
  --target <mode>     auto | imux | vscode | cursor | agy | windsurf | all | <dir> (default: auto)
  --version <ver>     Install a specific version from the official feed (default: latest)
  --channel <ch>      stable | prerelease (default: stable)
  --vsix <path>       Install from an offline .vsix file
  --local             Use local dist/clavue-code.vsix
  --force-downgrade   Allow installing an older version over a newer one
  -h, --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vsix)
      VSIX_PATH="${2:-}"
      shift 2
      ;;
    --local)
      USE_LOCAL=1
      shift
      ;;
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --version)
      REQUESTED_VERSION="${2:-}"
      shift 2
      ;;
    --channel)
      CHANNEL="${2:-}"
      shift 2
      ;;
    --force-downgrade)
      FORCE_DOWNGRADE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

sha256_of() {
  local f="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}' | tr '[:upper:]' '[:lower:]'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}' | tr '[:upper:]' '[:lower:]'
  else
    echo "Missing shasum/sha256sum" >&2
    exit 1
  fi
}

imux_managed_root() {
  case "$(uname -s)" in
    Darwin)
      printf '%s/Library/Application Support/imux/vscode-extensions\n' "$HOME"
      ;;
    *)
      printf '%s/.config/imux/vscode-extensions\n' "$HOME"
      ;;
  esac
}

imux_is_present() {
  [[ -d "/Applications/imux.app" ]] || [[ -d "$HOME/Library/Application Support/imux" ]] || [[ -d "$HOME/.config/imux" ]]
}

extract_vsix() {
  local vsix="$1"
  local dest="$2"
  if [[ "$(uname -s)" == "Darwin" ]] && [[ -x "/usr/bin/ditto" ]]; then
    /usr/bin/ditto -x -k "$vsix" "$dest"
  else
    need_cmd unzip
    unzip -q -o "$vsix" -d "$dest"
  fi
}

compare_semver_ge() {
  # Returns 0 if $1 >= $2, 1 if $1 < $2
  node -e '
    const parse = (s) => {
      let b = String(s || "").trim().replace(/^[vV]/, "").split("+")[0];
      const [core, pre] = b.split("-");
      const nums = core.split(".").map(Number);
      while (nums.length < 3) nums.push(0);
      return { nums, pre: pre ? pre.split(".") : [] };
    };
    const a = parse(process.argv[1]);
    const b = parse(process.argv[2]);
    for (let i = 0; i < 3; i++) {
      if (a.nums[i] !== b.nums[i]) process.exit(a.nums[i] > b.nums[i] ? 0 : 1);
    }
    if (a.pre.length === 0 && b.pre.length === 0) process.exit(0);
    if (a.pre.length === 0) process.exit(0);
    if (b.pre.length === 0) process.exit(1);
    process.exit(a.pre.join(".") >= b.pre.join(".") ? 0 : 1);
  ' "$1" "$2"
}

install_unpacked_atomic() {
  local vsix="$1"
  local root_dir="$2"
  local stage_extract
  stage_extract="$(mktemp -d)"

  extract_vsix "$vsix" "$stage_extract"
  local ext_src="${stage_extract}/extension"
  if [[ ! -f "${ext_src}/package.json" ]]; then
    ext_src="${stage_extract}"
  fi
  if [[ ! -f "${ext_src}/package.json" ]]; then
    rm -rf "$stage_extract"
    echo "Invalid VSIX: missing package.json" >&2
    exit 1
  fi

  local pkg_id pkg_ver
  pkg_id="$(node -e "const p=JSON.parse(require('fs').readFileSync('${ext_src}/package.json','utf8')); console.log((p.publisher+'.'+p.name).toLowerCase())")"
  pkg_ver="$(node -e "const p=JSON.parse(require('fs').readFileSync('${ext_src}/package.json','utf8')); console.log(p.version)")"
  if [[ "$pkg_id" != "clavue.clavue-code" ]]; then
    rm -rf "$stage_extract"
    echo "Unexpected extension id: ${pkg_id}" >&2
    exit 1
  fi

  mkdir -p "$root_dir"

  # Check existing versions under root_dir
  local existing_dirs=()
  local highest_ver=""
  local d
  for d in "${root_dir}"/*; do
    [[ -d "$d" ]] || continue
    [[ -f "${d}/package.json" ]] || continue
    local eid ever
    eid="$(node -e "try{const p=JSON.parse(require('fs').readFileSync('${d}/package.json','utf8')); console.log((p.publisher+'.'+p.name).toLowerCase())}catch{}" 2>/dev/null || true)"
    ever="$(node -e "try{const p=JSON.parse(require('fs').readFileSync('${d}/package.json','utf8')); console.log(p.version)}catch{}" 2>/dev/null || true)"
    if [[ "$eid" == "clavue.clavue-code" ]] && [[ -n "$ever" ]]; then
      existing_dirs+=("$d")
      if [[ -z "$highest_ver" ]] || compare_semver_ge "$ever" "$highest_ver"; then
        highest_ver="$ever"
      fi
    fi
  done

  if [[ -n "$highest_ver" ]] && [[ "$FORCE_DOWNGRADE" -eq 0 ]]; then
    if compare_semver_ge "$highest_ver" "$pkg_ver"; then
      rm -rf "$stage_extract"
      echo "[clavue-code] Already at v${highest_ver} in ${root_dir} (candidate v${pkg_ver}); skipping."
      return 0
    fi
  fi

  local sanitized_dir="${root_dir}/clavue.clavue-code-${pkg_ver}"
  local staging_dir="${root_dir}/.staging-clavue-${RANDOM}-$$"
  local backup_dir="${root_dir}/.backup-clavue-${RANDOM}-$$"
  mkdir -p "$staging_dir"
  cp -R "${ext_src}/." "${staging_dir}/"
  rm -rf "$stage_extract"

  mkdir -p "$backup_dir"
  local moved_backups=()
  for d in ${existing_dirs[@]+"${existing_dirs[@]}"}; do
    local base
    base="$(basename "$d")"
    mv "$d" "${backup_dir}/${base}"
    moved_backups+=("$base")
  done

  if mv "$staging_dir" "$sanitized_dir"; then
    rm -rf "$backup_dir"
    echo "[clavue-code] Installed clavue.clavue-code v${pkg_ver} -> ${sanitized_dir}"
  else
    rm -rf "$staging_dir" "$sanitized_dir"
    local base
    for base in ${moved_backups[@]+"${moved_backups[@]}"}; do
      mv "${backup_dir}/${base}" "${root_dir}/${base}" || true
    done
    rm -rf "$backup_dir"
    echo "[clavue-code] Failed to install; restored previous version." >&2
    exit 1
  fi
}

install_via_cli_or_dir() {
  local cli="$1"
  local fallback_dir="$2"
  local vsix="$3"
  if command -v "$cli" >/dev/null 2>&1; then
    echo "[clavue-code] Installing via ${cli} --install-extension..."
    "${cli}" --install-extension "$vsix" --force
    return 0
  fi
  if [[ -n "$fallback_dir" ]] && [[ -d "$(dirname "$fallback_dir")" ]]; then
    install_unpacked_atomic "$vsix" "$fallback_dir"
    return 0
  fi
  return 1
}

TMP_WORK="$(mktemp -d)"
trap 'rm -rf "${TMP_WORK}"' EXIT

if [[ "$USE_LOCAL" -eq 1 ]] && [[ -z "$VSIX_PATH" ]]; then
  VSIX_PATH="${ROOT_DIR}/dist/clavue-code.vsix"
fi

if [[ -z "$VSIX_PATH" ]]; then
  need_cmd curl
  need_cmd node
  FEED_FILE="${TMP_WORK}/feed.json"
  if ! curl -fsSL --max-time 15 "$FEED_URL" -o "$FEED_FILE" 2>/dev/null; then
    echo "[clavue-code] Primary feed unavailable, trying mirror..."
    curl -fsSL --max-time 15 "$FALLBACK_FEED_URL" -o "$FEED_FILE"
  fi

  RESOLVED="$(node -e '
    const fs = require("fs");
    const feed = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const reqVer = process.argv[2];
    const channel = process.argv[3];
    let entry = null;
    if (reqVer) {
      entry = (feed.releases || []).find(r => r.version === reqVer) || (feed.latest?.version === reqVer ? feed.latest : null);
    } else if (channel === "prerelease") {
      entry = feed.channels?.prerelease || feed.latest;
    } else {
      entry = feed.channels?.stable || feed.latest;
    }
    if (!entry || !entry.vsixUrl || !entry.sha256) process.exit(2);
    const urls = [entry.vsixUrl, ...(entry.mirrorUrls || [])].join("|");
    console.log(entry.version + "\t" + entry.sha256.toLowerCase() + "\t" + urls);
  ' "$FEED_FILE" "$REQUESTED_VERSION" "$CHANNEL")" || {
    echo "Could not resolve clavue-code release from feed." >&2
    exit 1
  }

  DL_VER="$(printf '%s' "$RESOLVED" | cut -f1)"
  EXPECTED_SHA="$(printf '%s' "$RESOLVED" | cut -f2)"
  URLS_PIPE="$(printf '%s' "$RESOLVED" | cut -f3)"
  VSIX_PATH="${TMP_WORK}/clavue-code-${DL_VER}.vsix"

  DOWNLOADED=0
  OLD_IFS="$IFS"
  IFS='|'
  for URL in $URLS_PIPE; do
    [[ -n "$URL" ]] || continue
    echo "[clavue-code] Downloading v${DL_VER} from ${URL}..."
    if curl -fsSL --max-time 60 "$URL" -o "$VSIX_PATH"; then
      DOWNLOADED=1
      break
    fi
  done
  IFS="$OLD_IFS"

  if [[ "$DOWNLOADED" -eq 0 ]]; then
    echo "Failed to download clavue-code v${DL_VER} from all URLs." >&2
    exit 1
  fi

  ACTUAL_SHA="$(sha256_of "$VSIX_PATH")"
  if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
    echo "SHA-256 mismatch! Expected ${EXPECTED_SHA}, got ${ACTUAL_SHA}" >&2
    exit 1
  fi
  echo "[clavue-code] SHA-256 verified (${ACTUAL_SHA})"
fi

if [[ ! -f "$VSIX_PATH" ]]; then
  echo "VSIX not found at ${VSIX_PATH}" >&2
  exit 1
fi

DID_INSTALL=0
case "$TARGET" in
  imux)
    install_unpacked_atomic "$VSIX_PATH" "$(imux_managed_root)"
    DID_INSTALL=1
    ;;
  vscode)
    install_via_cli_or_dir "code" "$HOME/.vscode/extensions" "$VSIX_PATH" && DID_INSTALL=1 || true
    ;;
  cursor)
    install_via_cli_or_dir "cursor" "$HOME/.cursor/extensions" "$VSIX_PATH" && DID_INSTALL=1 || true
    ;;
  agy)
    install_via_cli_or_dir "agy" "$HOME/.antigravity/extensions" "$VSIX_PATH" && DID_INSTALL=1 || true
    ;;
  windsurf)
    install_via_cli_or_dir "windsurf" "$HOME/.windsurf/extensions" "$VSIX_PATH" && DID_INSTALL=1 || true
    ;;
  all)
    install_unpacked_atomic "$VSIX_PATH" "$(imux_managed_root)"
    DID_INSTALL=1
    for pair in "code:$HOME/.vscode/extensions" "cursor:$HOME/.cursor/extensions" "agy:$HOME/.antigravity/extensions"; do
      c="${pair%%:*}"
      d="${pair#*:}"
      if command -v "$c" >/dev/null 2>&1; then
        install_via_cli_or_dir "$c" "$d" "$VSIX_PATH" || true
      fi
    done
    ;;
  auto)
    if imux_is_present; then
      install_unpacked_atomic "$VSIX_PATH" "$(imux_managed_root)"
      DID_INSTALL=1
    fi
    for cli in code cursor agy; do
      if command -v "$cli" >/dev/null 2>&1; then
        install_via_cli_or_dir "$cli" "" "$VSIX_PATH" && DID_INSTALL=1 || true
      fi
    done
    if [[ "$DID_INSTALL" -eq 0 ]]; then
      echo "No imux, VS Code, Cursor, or Antigravity installation detected." >&2
      echo "Pass --target imux, --target vscode, or --target <extensions-dir>." >&2
      exit 1
    fi
    ;;
  *)
    install_unpacked_atomic "$VSIX_PATH" "$TARGET"
    DID_INSTALL=1
    ;;
esac

if [[ "$DID_INSTALL" -eq 1 ]]; then
  echo "[clavue-code] Done."
fi
