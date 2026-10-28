# Clavue Public Distribution

Public distribution artifacts for Clavue (v1 alongside historical v8).

## Install clavue-v1 (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/mycode699/clavue-public/main/install.sh | bash
```

Pin:

```bash
curl -fsSL https://github.com/mycode699/clavue-public/releases/download/v1.62.18/install.sh | bash -s -- 1.62.18
```

npm fallback:

```bash
npm install -g clavue-v1@1.62.18
```

Current release: **1.62.18** — TUI/input fixes, tool-narration early cut, and ui/visual Desktop SNAPSHOT closed loop (real image pixels required; stubbed history reattached). Absolute Full Access unchanged; includes 1.62.10–1.62.17 gates.

The installer resolves the highest **v1.*** release via the GitHub API (never `/releases/latest`, which may still point at v8).

## Legacy clavue (v8)

```bash
npm install -g clavue
```
