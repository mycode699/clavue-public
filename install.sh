#!/usr/bin/env bash
# clavue-v1 installer — public GitHub first, npm fallback (no auth required)
#
# One-liner (install.sh resolves the highest v1.* on clavue-public; it never
# trusts /releases/latest, which may still be a v8 tag):
#
#   curl -fsSL https://raw.githubusercontent.com/mycode699/clavue-public/main/install.sh | bash
#
# Pin a version:
#
#   curl -fsSL https://github.com/mycode699/clavue-public/releases/download/v1.42.3/install.sh | bash -s -- 1.42.3
#
# Force npm:
#
#   CLAVUE_INSTALL_SOURCE=npm bash install.sh
#
# Env:
#   CLAVUE_INSTALL_SOURCE=github|npm   (default: github)
#   CLAVUE_PACKAGE                    (default: clavue-v1)
#   CLAVUE_VERSION / $1               (default: latest → highest public v1.*)
#
set -euo pipefail

PACKAGE="${CLAVUE_PACKAGE:-clavue-v1}"
VERSION_INPUT="${1:-${CLAVUE_VERSION:-latest}}"
PUBLIC_REPO="${CLAVUE_PUBLIC_REPO:-mycode699/clavue-public}"
PUBLIC_API="https://api.github.com/repos/${PUBLIC_REPO}/releases"
PUBLIC_DOWNLOAD_BASE="https://github.com/${PUBLIC_REPO}/releases/download"
INSTALL_SOURCE="${CLAVUE_INSTALL_SOURCE:-github}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

check_node() {
  need_cmd node
  local node_major node_minor
  node_major="$(node -p "process.versions.node.split('.')[0]")"
  node_minor="$(node -p "process.versions.node.split('.')[1]")"
  if [[ -z "$node_major" || "$node_major" -lt 22 ]] ||
    [[ "$node_major" -eq 22 && "$node_minor" -lt 18 ]]; then
    printf 'clavue-v1 requires Node.js 22.18 or newer. Found: %s\n' "$(node -v)" >&2
    exit 1
  fi
}

# stdin: releases JSON array. stdout: version<TAB>tag<TAB>tgz_url
pick_highest_v1() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, re, sys
tag_re = re.compile(r"^v(1\.\d+\.\d+(?:[.-][0-9A-Za-z.-]+)?)$")
tgz_re = re.compile(r"^clavue-v1-(1\.\d+\.\d+(?:[.-][0-9A-Za-z.-]+)?)\.tgz$")

def semver_key(v):
    out = []
    for p in re.split(r"[.+-]", v):
        try: out.append(int(p))
        except ValueError: out.append(0)
    return out

raw = sys.stdin.read().strip()
if not raw: sys.exit(1)
raw = raw.replace("][", ",")
try: releases = json.loads(raw)
except Exception: sys.exit(1)
if not isinstance(releases, list): sys.exit(1)
best = None
for rel in releases:
    if not isinstance(rel, dict) or rel.get("draft") or rel.get("prerelease"):
        continue
    tag = rel.get("tag_name") or ""
    m = tag_re.match(tag)
    if not m: continue
    version = m.group(1)
    tgz_url = None
    for asset in rel.get("assets") or []:
        name = (asset or {}).get("name") or ""
        tm = tgz_re.match(name)
        if tm and tm.group(1) == version:
            tgz_url = asset.get("browser_download_url")
            break
    if not tgz_url: continue
    cand = (semver_key(version), version, tag, tgz_url)
    if best is None or cand[0] > best[0]:
        best = cand
if best is None: sys.exit(1)
_, version, tag, url = best
print("%s\t%s\t%s" % (version, tag, url))
'
    return $?
  fi
  node -e '
const fs = require("fs");
let raw = fs.readFileSync(0, "utf8").trim();
if (!raw) process.exit(1);
raw = raw.replace("][", ",");
let releases; try { releases = JSON.parse(raw); } catch { process.exit(1); }
if (!Array.isArray(releases)) process.exit(1);
const tagRe = /^v(1\.\d+\.\d+(?:[.-][0-9A-Za-z.-]+)?)$/;
const tgzRe = /^clavue-v1-(1\.\d+\.\d+(?:[.-][0-9A-Za-z.-]+)?)\.tgz$/;
const key = (v) => v.split(/[.+-]/).map((p) => parseInt(p, 10) || 0);
const cmp = (a, b) => { for (let i = 0; i < Math.max(a.length, b.length); i++) { const da = a[i] || 0, db = b[i] || 0; if (da !== db) return da - db; } return 0; };
let best = null;
for (const rel of releases) {
  if (!rel || rel.draft || rel.prerelease) continue;
  const tm = String(rel.tag_name || "").match(tagRe);
  if (!tm) continue;
  const version = tm[1];
  let tgzUrl = null;
  for (const asset of rel.assets || []) {
    const am = String(asset.name || "").match(tgzRe);
    if (am && am[1] === version) { tgzUrl = asset.browser_download_url; break; }
  }
  if (!tgzUrl) continue;
  const cand = { k: key(version), version, tag: rel.tag_name, url: tgzUrl };
  if (!best || cmp(cand.k, best.k) > 0) best = cand;
}
if (!best) process.exit(1);
process.stdout.write(best.version + "\t" + best.tag + "\t" + best.url + "\n");
'
}

resolve_latest_v1_from_github() {
  need_cmd curl
  local page payload
  local all=""
  local first=1
  for page in 1 2 3 4 5; do
    payload="$(curl -fsSL --max-time 8 \
      -H "Accept: application/vnd.github+json" \
      -H "User-Agent: clavue-v1-installer" \
      "${PUBLIC_API}?per_page=30&page=${page}" 2>/dev/null || true)"
    if [[ -z "$payload" || "$payload" == "[]" ]]; then
      break
    fi
    local inner="${payload#\[}"
    inner="${inner%\]}"
    if [[ -z "$inner" ]]; then
      break
    fi
    if [[ "$first" -eq 1 ]]; then
      all="[${inner}"
      first=0
    else
      all="${all},${inner}"
    fi
    if printf "%s" "$payload" | grep -qE '"tag_name":[[:space:]]*"v1\.'; then
      break
    fi
    local count
    count="$(printf "%s" "$payload" | grep -c '"tag_name"' || true)"
    if [[ "${count:-0}" -lt 30 ]]; then
      break
    fi
  done
  if [[ "$first" -eq 1 ]]; then
    return 1
  fi
  all="${all}]"
  printf "%s" "$all" | pick_highest_v1
}

resolve_version_and_url() {
  if [[ "$VERSION_INPUT" != "latest" ]]; then
    local version="${VERSION_INPUT#v}"
    local tag="v${version}"
    local url="${PUBLIC_DOWNLOAD_BASE}/${tag}/clavue-v1-${version}.tgz"
    printf "%s\t%s\t%s\n" "$version" "$tag" "$url"
    return 0
  fi
  resolve_latest_v1_from_github
}

install_from_github() {
  local version tag url tmp tgz resolved
  resolved="$(resolve_version_and_url)" || return 1
  IFS=$'\t' read -r version tag url <<<"$resolved"
  if [[ -z "${version:-}" || -z "${url:-}" ]]; then
    return 1
  fi

  printf "Installing %s@%s from GitHub (%s)…\n" "$PACKAGE" "$version" "$PUBLIC_REPO"
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf \"$tmp\"" RETURN
  tgz="${tmp}/clavue-v1-${version}.tgz"
  if ! curl -fsSL --max-time 180 -o "$tgz" "$url"; then
    printf "Failed to download %s\n" "$url" >&2
    return 1
  fi
  npm install -g "$tgz"
  printf "Installed %s@%s from GitHub\n" "$PACKAGE" "$version"
  return 0
}

install_from_npm() {
  local version
  if [[ "$VERSION_INPUT" != "latest" ]]; then
    version="${VERSION_INPUT#v}"
  else
    version="$(npm view "$PACKAGE" version)"
  fi
  if [[ -z "$version" ]]; then
    printf "Unable to determine the latest %s version from npm.\n" "$PACKAGE" >&2
    return 1
  fi
  printf "Installing %s@%s globally from npm…\n" "$PACKAGE" "$version"
  printf "For one-shot use without a global install, run: npx -y %s@%s\n" "$PACKAGE" "$version"
  npm install -g "${PACKAGE}@${version}"
  printf "Installed %s@%s globally\n" "$PACKAGE" "$version"
}

main() {
  need_cmd npm
  need_cmd curl
  check_node

  local ok=0
  if [[ "$INSTALL_SOURCE" != "npm" ]]; then
    if install_from_github; then
      ok=1
    else
      printf "GitHub install unavailable; falling back to npm…\n" >&2
    fi
  fi
  if [[ "$ok" -ne 1 ]]; then
    install_from_npm || exit 1
  fi

  printf "Available commands after install: clavue-v1\n"
  clavue-v1 --version || true

  printf "\nNext step:\n"
  printf "  Run: clavue-v1\n"
  printf "  First launch opens API setup. Choose \"自定义 API 配置\" to enter your API URL, key, and optional model slots.\n"
  printf "  You can reopen setup any time with: clavue-v1 provider\n"
  printf "  Upgrade later with: clavue-v1 update   (or re-run this install.sh)\n"
}

main "$@"
