# Clavue Public Distribution

Public distribution artifacts for Clavue (v1 alongside historical v8).

## Install clavue-v1 (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/mycode699/clavue-public/main/install.sh | bash
```

Pin:

```bash
curl -fsSL https://github.com/mycode699/clavue-public/releases/download/v1.62.14/install.sh | bash -s -- 1.62.14
```

npm fallback:

```bash
npm install -g clavue-v1@1.62.14
```

Current release: **1.62.14** — each CLI process gets its own browser profile (`clavue-browser-<pid>-<nonce>`) and free debug port; default no longer attaches to 9222/shared 9333 or steals another session's tab; prefers automation Chromium (Playwright cache / Chrome for Testing / system chromium) then system Chrome with isolated profile only; opt-in `CLAVUE_CHROME_PORT` / `CLAVUE_BROWSER_ATTACH=1`; `CLAVUE_BROWSER_HEADLESS=1`; Browser STEP still uses clavue-jev; Absolute Full Access unchanged; includes 1.62.13 sticky screenshots. Features, configuration (`CLAVUE_*` settings) and developer workflow are documented in the [clavue-v1 README](https://github.com/mycode699/clavue-v1#readme); per-release changes are in [CHANGELOG.md](https://github.com/mycode699/clavue-v1/blob/main/CHANGELOG.md) and [`docs/release-notes-v1.62.14.md`](https://github.com/mycode699/clavue-v1/blob/main/docs/release-notes-v1.62.14.md). Requires Node.js >= 22.18.

The installer resolves the highest **v1.*** release via the GitHub API (never `/releases/latest`, which may still point at v8).

## Legacy clavue (v8)

```bash
npm install -g clavue
```
