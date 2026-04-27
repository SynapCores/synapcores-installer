# synapcores-installer

Hosts the bootstrap installer for **SynapCores Community Edition** at
[`https://get.synapcores.com`](https://get.synapcores.com).

## Quick install

```bash
curl -fsSL https://get.synapcores.com/install.sh | sh
```

Binary-only (skip the systemd unit + system user):

```bash
curl -fsSL https://get.synapcores.com/install.sh | SYNAPCORES_BINARY_ONLY=1 sh
```

Pin a specific release:

```bash
curl -fsSL https://get.synapcores.com/install.sh | SYNAPCORES_VERSION=v1.0.0-ce sh
```

---

## Supported platforms

CE binaries are built on every release for these four targets:

| Platform | Triple | Runner | Notes |
| --- | --- | --- | --- |
| Linux x86\_64 | `x86_64-unknown-linux-gnu` | `ubuntu-22.04` | Most servers; AWS/GCP/Azure VMs |
| Linux aarch64 | `aarch64-unknown-linux-gnu` | `ubuntu-22.04-arm` | AWS Graviton, Raspberry Pi 4/5 |
| macOS x86\_64 | `x86_64-apple-darwin` | `macos-13` | Intel Macs |
| macOS aarch64 | `aarch64-apple-darwin` | `macos-14` | Apple Silicon (M1/M2/M3/M4) |

Linux binaries are built against **glibc 2.35** (Ubuntu 22.04), so they run on
Ubuntu 22.04+, Debian 12+, RHEL 9 / Rocky 9 / Alma 9. They will **not** run
on CentOS 7 / RHEL 7 (glibc too old). Windows is not supported in CE — run
SynapCores under WSL 2 or in a Linux VM.

## Hardware requirements

Recommended minimums for a comfortable single-tenant deployment:

| Resource | Minimum | Recommended |
| --- | --- | --- |
| CPU | 2 cores, x86\_64-v2 | 4+ cores, x86\_64-v3 (AVX2) |
| RAM | 4 GB | 8 GB+ (LLM inference needs headroom) |
| Disk | 10 GB free in the data dir | 50+ GB SSD (vector indexes are I/O-heavy) |
| File descriptors | `ulimit -n` ≥ 4096 | 65536 (the systemd unit sets this) |
| Network | TCP `8080` (HTTP) + `8443` (TLS) free | Same |
| GPU | Not required | Optional — improves LLM inference throughput |

The CE binary runs out of the box on a small VM (4 GB / 2 vCPU). Throughput
on big workloads is bounded by RAM (HNSW vector indexes are RAM-resident)
and AVX2 availability (llama-cpp inference is much slower without it).

## What the installer DOES check

- OS is Linux or macOS (bails otherwise)
- Architecture is `x86_64` or `aarch64` (bails otherwise)
- Tarball SHA-256 matches the published checksum
- Downloaded binary self-reports as Community (rejects an Enterprise build)

## What the installer DOES NOT check

These are **your** responsibility before running the installer in production:

- RAM headroom (the installer doesn't measure free memory)
- Disk space at the data dir
- glibc version (you'll get a runtime symbol error on older distros, not an
  install-time refusal)
- Whether `:8080` / `:8443` are already in use
- File descriptor limits (the systemd unit sets `LimitNOFILE=65536`, but a
  binary-only install or `docker run` won't get that for free)
- AVX2 availability (llama-cpp will work without it but is slower)

If you want, run the included `synapcores --version` after install to confirm
the binary boots; the first-time start in `journalctl -u synapcores -f` will
flag missing config or port conflicts immediately.

## Local LLM inference

CE ships with **built-in local LLM inference** via the embedded
[`llama-cpp`](https://github.com/ggerganov/llama.cpp) Rust binding. The
`llm-inference` Cargo feature is on by default — there is nothing extra
to install for AI chat, NL2SQL, or embedding generation to work. CE uses
quantized GGUF models loaded in-process.

### Ollama is *not* required and *not* installed

[Ollama](https://ollama.com) is **optional**. The installer does not
download or configure Ollama. SynapCores integrates with Ollama only if
you explicitly point its AI provider config at an Ollama HTTP endpoint
(e.g. `http://localhost:11434`). If you'd rather use Ollama than the
embedded llama-cpp:

1. Install Ollama yourself: `curl -fsSL https://ollama.com/install.sh | sh`
2. Pull whichever models you want: `ollama pull llama3.2`
3. In your gateway config, set the AI provider to `ollama` and point its
   `base_url` at `http://localhost:11434`.

Same story for OpenAI, Anthropic, etc. — these are integration targets,
not installer dependencies.

## What `install.sh` does

1. Detects the host OS + architecture
2. Resolves the latest SynapCores CE release from
   [`mataluis2k/aidb` GitHub Releases](https://github.com/mataluis2k/aidb/releases)
   (or honors `SYNAPCORES_VERSION=vX.Y.Z`)
3. Downloads the matching tarball + SHA-256 checksum and verifies them
4. Installs `synapcores` to `/usr/local/bin`
5. Hands off to the local `install-ce.sh` (bundled in the release tarball)
   which creates the system user, lays out `/opt/synapcores`, and installs a
   hardened systemd unit (`NoNewPrivileges`, `ProtectSystem=strict`,
   `LimitNOFILE=65536`)

## Updating the script

The canonical source lives at
[`mataluis2k/aidb:scripts/install/get-synapcores-ce.sh`](https://github.com/mataluis2k/aidb/blob/release/community-edition-v1/scripts/install/get-synapcores-ce.sh).

When that script changes, copy the new contents into this repo's `install.sh`
on `main` and the GitHub Pages cache will pick it up within a few minutes.

## DNS

`get.synapcores.com` is a CNAME pointing at `synapcores.github.io.`.
GitHub Pages auto-provisions and renews a Let's Encrypt certificate for
the custom domain after the CNAME is verified.
