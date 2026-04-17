# Clavue Public Distribution

This repository is a public distribution surface for Clavue release artifacts.

It does not contain the private source tree.

## Install from npm

```bash
npm install -g clavue
clavue --version
```

## Install with the helper script

```bash
curl -fsSL https://raw.githubusercontent.com/mycode699/clavue-public/main/install.sh | bash
```

## Included artifacts

- `install.sh`
- `SHA256SUMS`
- `manifest.json`
- versioned release archives under `artifacts/`

## npm package surface

The published npm package exposes the built runtime only, not development source files.
