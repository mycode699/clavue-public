# Clavue Public Distribution

Public distribution artifacts for Clavue (v1 alongside historical v8).

## Install clavue-v1 (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/mycode699/clavue-public/main/install.sh | bash
```

Pin:

```bash
curl -fsSL https://github.com/mycode699/clavue-public/releases/download/v1.62.16/install.sh | bash -s -- 1.62.16
```

npm fallback:

```bash
npm install -g clavue-v1@1.62.16
```

Current release: **1.62.16** — 「多开几个 clavue」 wakes lead-session Agent (+ TeamCreate when workers share a task list) with worktree / background `-p` (no default `/parallel` rewrite; panes need 「确认开分屏」); slash cleanup demotes `/parallel` to typed-only and hides stale aliases; Absolute Full Access unchanged; includes 1.62.14 per-CLI browser isolation. Features, configuration (`CLAVUE_*` settings) and developer workflow are documented in the [clavue-v1 README](https://github.com/mycode699/clavue-v1#readme); per-release changes are in [CHANGELOG.md](https://github.com/mycode699/clavue-v1/blob/main/CHANGELOG.md) and [`docs/release-notes-v1.62.16.md`](https://github.com/mycode699/clavue-v1/blob/main/docs/release-notes-v1.62.16.md). Requires Node.js >= 22.18.

The installer resolves the highest **v1.*** release via the GitHub API (never `/releases/latest`, which may still point at v8).

## Legacy clavue (v8)

```bash
npm install -g clavue
```
