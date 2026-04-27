# synapcores-installer

Hosts the bootstrap installer for **SynapCores Community Edition** at
[`https://get.synapcores.com`](https://get.synapcores.com).

## What this repo is

A single-purpose static site, served via GitHub Pages, that exists so
the documented one-liner

```bash
curl -fsSL https://get.synapcores.com/install.sh | sh
```

resolves to the [`install.sh`](install.sh) script in this repo.

## What `install.sh` does

1. Detects the host OS + architecture
2. Resolves the latest SynapCores CE release from
   [`SynapCores/aidb` GitHub Releases](https://github.com/mataluis2k/aidb/releases)
   (or honors `SYNAPCORES_VERSION=vX.Y.Z`)
3. Downloads the matching tarball + SHA-256 checksum and verifies them
4. Installs `synapcores` to `/usr/local/bin`
5. Hands off to the local `install-ce.sh` (bundled in the release
   tarball) which creates the system user, lays out
   `/opt/synapcores`, and installs the systemd unit

For binary-only installs (skip system setup):

```bash
curl -fsSL https://get.synapcores.com/install.sh | SYNAPCORES_BINARY_ONLY=1 sh
```

## Updating the script

The canonical source lives at
[`mataluis2k/aidb:scripts/install/get-synapcores-ce.sh`](https://github.com/mataluis2k/aidb/blob/release/community-edition-v1/scripts/install/get-synapcores-ce.sh).

When that script changes, copy the new contents into this repo's
`install.sh` on `main` and the CDN cache will pick it up within a few
minutes (GitHub Pages cache TTL is short).

## DNS

`get.synapcores.com` is a CNAME record pointing at
`synapcores.github.io.`.

GitHub Pages auto-provisions and renews a Let's Encrypt certificate
for the custom domain.
