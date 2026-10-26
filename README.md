# Clavue Public Distribution

Public distribution artifacts for Clavue (v1 alongside historical v8).

## Install clavue-v1 (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/mycode699/clavue-public/main/install.sh | bash
```

Pin:

```bash
curl -fsSL https://github.com/mycode699/clavue-public/releases/download/v1.62.6/install.sh | bash -s -- 1.62.6
```

npm fallback:

```bash
npm install -g clavue-v1@1.62.6
```

Current release: **1.62.6** — second local Bash grep/find/ls gated to Grep/Glob/Survey; adapter -A/-B/-C sort|uniq; 1.62.4/1.62.5 unchanged. Features, configuration (`CLAVUE_*` settings) and developer workflow are documented in the [clavue-v1 README](https://github.com/mycode699/clavue-v1#readme); per-release changes are in [CHANGELOG.md](https://github.com/mycode699/clavue-v1/blob/main/CHANGELOG.md) and [`docs/release-notes-v1.62.6.md`](https://github.com/mycode699/clavue-v1/blob/main/docs/release-notes-v1.62.6.md). Requires Node.js >= 22.18.

The installer resolves the highest **v1.*** release via the GitHub API (never `/releases/latest`, which may still point at v8).

## Legacy clavue (v8)

```bash
npm install -g clavue
```
