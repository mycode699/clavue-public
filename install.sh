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
#   curl -fsSL https://github.com/mycode699/clavue-public/releases/download/v1.43.0/install.sh | bash -s -- 1.43.0
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

# Terminal palette (respects NO_COLOR and non-TTY stdout cleanly)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET='\033[0m'
  C_BOLD='\033[1m'
  C_DIM='\033[38;2;156;166;180m'
  C_SKY='\033[1;38;2;122;180;232m'
  C_SILVER='\033[38;2;226;231;239m'
  C_GREEN='\033[38;2;78;186;101m'
  C_AMBER='\033[38;2;255;193;7m'
  C_RED='\033[38;2;255;107;128m'
  C_VIOLET='\033[38;2;177;185;249m'
  USE_COLOR=1
else
  C_RESET=''
  C_BOLD=''
  C_DIM=''
  C_SKY=''
  C_SILVER=''
  C_GREEN=''
  C_AMBER=''
  C_RED=''
  C_VIOLET=''
  USE_COLOR=0
fi

print_banner() {
  if [[ "$USE_COLOR" -eq 1 ]]; then
    printf '\n'
    printf '  %b\n' '    \033[38;2;193;210;68m▄\033[0m\033[38;2;230;208;60;48;2;217;209;63m▀\033[0m\033[38;2;239;201;56;48;2;238;204;57m▀\033[0m\033[38;2;243;191;54;48;2;243;192;54m▀\033[0m\033[38;2;247;180;51;48;2;248;179;50m▀\033[0m\033[38;2;252;170;48;48;2;253;167;47m▀\033[0m\033[38;2;255;161;46;48;2;255;156;49m▀\033[0m\033[38;2;255;145;54m▄\033[0m'
    printf '  %b   %bclavue%b %b·%b %b克拉维%b\n' '  \033[38;2;118;214;87m▄\033[0m\033[38;2;154;212;78;48;2;130;213;84m▀\033[0m\033[38;2;174;211;73;48;2;148;212;79m▀\033[0m\033[38;2;200;210;67;48;2;174;211;73m▀\033[0m\033[38;2;234;208;59m▀\033[0m\033[38;2;242;193;54m▀\033[0m  \033[38;2;255;148;53m▀\033[0m\033[38;2;255;137;58m▀\033[0m' "$C_SKY" "$C_RESET" "$C_DIM" "$C_RESET" "$C_SILVER" "$C_RESET"
    printf '  %b   %b云起东方 · 龙行代码%b\n' '\033[38;2;90;212;121m▄\033[0m\033[38;2;101;213;105;48;2;91;212;120m▀\033[0m\033[38;2;103;213;101;48;2;91;212;118m▀\033[0m\033[38;2;107;213;95;48;2;93;212;116m▀\033[0m\033[38;2;115;214;87m▀\033[0m  \033[38;2;253;146;104m▄\033[0m\033[38;2;255;182;72;48;2;253;146;104m▀\033[0m\033[38;2;255;182;72;48;2;253;146;104m▀\033[0m\033[38;2;253;146;104m▄\033[0m ' "$C_VIOLET" "$C_RESET"
    printf '  %b   %bExecution-first · 4-Slot AI Coding Console%b\n' '\033[38;2;81;211;134m▀\033[0m\033[38;2;80;210;135;48;2;70;209;150m▀\033[0m\033[38;2;79;210;137;48;2;67;209;155m▀\033[0m\033[38;2;78;210;139;48;2;63;209;160m▀\033[0m\033[38;2;58;208;169m▄\033[0m  \033[38;2;250;106;138m▀\033[0m\033[38;2;250;106;138;48;2;216;108;197m▀\033[0m\033[38;2;250;106;138;48;2;216;108;197m▀\033[0m\033[38;2;250;106;138m▀\033[0m ' "$C_DIM" "$C_RESET"
    printf '  %b   %bInstaller · GitHub Releases / npm%b\n' '  \033[38;2;58;207;171m▀\033[0m\033[38;2;60;205;179;48;2;63;201;195m▀\033[0m\033[38;2;62;202;191;48;2;65;197;208m▀\033[0m\033[38;2;65;197;208;48;2;68;193;225m▀\033[0m\033[38;2;72;187;248m▄\033[0m\033[38;2;76;170;251m▄\033[0m  \033[38;2;103;126;253m▄\033[0m\033[38;2;118;120;253m▄\033[0m' "$C_DIM" "$C_RESET"
    printf '  %b\n\n' '    \033[38;2;67;194;221m▀\033[0m\033[38;2;70;190;237;48;2;71;187;245m▀\033[0m\033[38;2;73;182;250;48;2;74;179;251m▀\033[0m\033[38;2;76;168;251;48;2;76;167;251m▀\033[0m\033[38;2;79;154;252;48;2;79;155;252m▀\033[0m\033[38;2;83;140;254;48;2;82;144;253m▀\033[0m\033[38;2;92;131;254;48;2;84;134;254m▀\033[0m\033[38;2;106;125;253m▀\033[0m'
  else
    printf 'clavue · 克拉维 — Execution-first · 4-Slot AI Coding Console\n'
  fi
}

log_step() {
  printf '%b▸%b %s\n' "$C_SKY" "$C_RESET" "$1"
}

log_ok() {
  printf '%b●%b %s\n' "$C_GREEN" "$C_RESET" "$1"
}

log_warn() {
  printf '%b▲%b %s\n' "$C_AMBER" "$C_RESET" "$1" >&2
}

log_err() {
  printf '%b✗%b %s\n' "$C_RED" "$C_RESET" "$1" >&2
}

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

  log_step "Installing ${PACKAGE}@${version} from GitHub (${PUBLIC_REPO})…"
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf \"$tmp\"" RETURN
  tgz="${tmp}/clavue-v1-${version}.tgz"
  if ! curl -fsSL --max-time 180 -o "$tgz" "$url"; then
    log_err "Failed to download ${url}"
    return 1
  fi
  npm install -g "$tgz"
  log_ok "Installed ${PACKAGE}@${version} from GitHub"
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
    log_err "Unable to determine the latest ${PACKAGE} version from npm."
    return 1
  fi
  log_step "Installing ${PACKAGE}@${version} globally from npm…"
  printf '  %bFor one-shot use without a global install, run: npx -y %s@%s%b\n' "$C_DIM" "$PACKAGE" "$version" "$C_RESET"
  npm install -g "${PACKAGE}@${version}"
  log_ok "Installed ${PACKAGE}@${version} globally"
}

main() {
  print_banner
  need_cmd npm
  need_cmd curl
  check_node

  local ok=0
  if [[ "$INSTALL_SOURCE" != "npm" ]]; then
    if install_from_github; then
      ok=1
    else
      log_warn "GitHub install unavailable; falling back to npm…"
    fi
  fi
  if [[ "$ok" -ne 1 ]]; then
    install_from_npm || exit 1
  fi

  printf '\n%b●%b Available commands after install: clavue, clavue-v1\n' "$C_GREEN" "$C_RESET"
  clavue --version || true
  clavue-v1 --version || true

  printf '\n%bNext step:%b\n' "$C_SKY" "$C_RESET"
  printf '  %b❯%b %bRun: clavue%b\n' "$C_VIOLET" "$C_RESET" "$C_BOLD" "$C_RESET"
  printf '  %bThe same CLI is also: clavue-v1%b\n' "$C_DIM" "$C_RESET"
  printf '  First launch opens API setup. Choose %b用克拉维账号开始%b, or %b我有自己的 Key%b. Later, /provider still offers %b自定义 API 配置%b for an API URL, key, and optional model slots.\n' "$C_SKY" "$C_RESET" "$C_AMBER" "$C_RESET" "$C_VIOLET" "$C_RESET"
  printf '  %bYou can reopen setup any time with: clavue provider   (or clavue-v1 provider)%b\n' "$C_DIM" "$C_RESET"
  printf '  %bUpgrade later with: clavue update   (or clavue-v1 update, or re-run this install.sh)%b\n\n' "$C_DIM" "$C_RESET"
}

main "$@"
