#!/bin/sh
#
# get-synapcores-ce.sh — one-line remote installer for SynapCores
# Community Edition.
#
# Hosted at: https://get.synapcores.com
#
# Usage:
#   curl -fsSL https://get.synapcores.com/install.sh | sh
#
# Quick userland test (no sudo, no system service, no /opt or /etc):
#   curl -fsSL https://get.synapcores.com/install.sh | SYNAPCORES_USER_INSTALL=1 sh
#
# Or, to pin a specific release:
#   curl -fsSL https://get.synapcores.com/install.sh | SYNAPCORES_VERSION=v1.2.0 sh
#
# Environment variables:
#   SYNAPCORES_USER_INSTALL=1   Install for the current user only:
#                               binary → ~/.local/bin, config + data →
#                               ~/.synapcores, no system user, no
#                               systemd unit. Good for kicking the
#                               tires without touching system state.
#   SYNAPCORES_PREFIX=<dir>     Override the binary install dir
#                               (default: /usr/local/bin in system
#                               mode, ~/.local/bin in user mode).
#   SYNAPCORES_BINARY_ONLY=1    Drop the binary and stop. Operator
#                               handles config and service themselves.
#   SYNAPCORES_VERSION=<tag>    Pin a specific release tag.
#   SYNAPCORES_NONINTERACTIVE=1 Skip prompts; assume safe defaults.
#   SYNAPCORES_WITH_NLI=1      Install and enable semantic verification.
#   SYNAPCORES_NLI_MODEL=...   Curated alias (default nli-default; nli-xsmall optional).
#   SYNAPCORES_NO_MODEL_DOWNLOAD=1  Use previously imported models, without pulling.
#
# Written in POSIX sh on purpose: when invoked via `curl ... | sh`,
# Debian/Ubuntu's /bin/sh is dash, not bash. Bash-only constructs like
# `[[ ... ]]`, `set -o pipefail`, `local`, `$EUID`, and arrays MUST NOT
# appear in this file. If you need them, branch out into a helper that
# bash can run after the binary is on disk.
#
# What it does:
#   1. Detects the OS and architecture
#   2. Resolves the latest GitHub release tag (or honors $SYNAPCORES_VERSION)
#   3. Downloads the matching binary tarball + checksum
#   4. Verifies the checksum
#   5. Drops the binary at /usr/local/bin/synapcores (system mode,
#      requires sudo) or ~/.local/bin/synapcores (user mode, no sudo).
#   6. Hands off to install-ce.sh for setup (system: useradd, /opt
#      layout, /etc/systemd unit; user: ~/.synapcores layout, no
#      systemd unit). Skipped entirely if SYNAPCORES_BINARY_ONLY is set.
#
# Requirements:
#   - curl
#   - tar
#   - sha256sum (or shasum -a 256)

set -eu

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

GITHUB_REPO="${SYNAPCORES_REPO:-SynapCores/synapcores-releases}"
RELEASE_BASE="https://github.com/${GITHUB_REPO}/releases"
PINNED_VERSION="${SYNAPCORES_VERSION:-}"
BINARY_ONLY="${SYNAPCORES_BINARY_ONLY:-}"
# User-mode install: opt in via SYNAPCORES_USER_INSTALL=1, or via
# interactive prompt (Linux only) when stdin is a tty and the operator
# hasn't set the env var. Default = system mode.
USER_INSTALL="${SYNAPCORES_USER_INSTALL:-}"
# INSTALL_PREFIX default depends on USER_INSTALL — resolved after the
# (possibly interactive) prompt below so we honor a late opt-in.
INSTALL_PREFIX="${SYNAPCORES_PREFIX:-}"
NLI_OPT_IN="${SYNAPCORES_WITH_NLI:-0}"
NLI_MODEL="${SYNAPCORES_NLI_MODEL:-nli-default}"

# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------

log()   { printf '\033[1;34m[get-synapcores]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[get-synapcores]\033[0m %s\n' "$*" >&2; }
fail()  { printf '\033[1;31m[get-synapcores]\033[0m %s\n' "$*" >&2; exit 1; }

case "$NLI_OPT_IN" in
    1|true|yes) NLI_OPT_IN=1 ;;
    0|false|no|"") NLI_OPT_IN=0 ;;
    *) fail "SYNAPCORES_WITH_NLI must be 0 or 1" ;;
esac
case "$NLI_MODEL" in
    nli-default|nli-small|nli-xsmall) ;;
    *) fail "Unknown NLI model; use nli-default or nli-xsmall" ;;
esac

require() {
    command -v "$1" >/dev/null 2>&1 || fail "missing required tool: $1"
}

require curl
require tar

if command -v sha256sum >/dev/null 2>&1; then
    SHA256_TOOL="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    SHA256_TOOL="shasum -a 256"
else
    fail "missing required tool: sha256sum (or shasum)"
fi

# ---------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------

# detect_platform: prints "<os>-<arch>" to stdout. Exits non-zero if
# the platform is unsupported. POSIX sh has no `local`, so we use
# uppercase variable names to make it obvious these survive the call.
detect_platform() {
    DETECTED_OS=$(uname -s)
    DETECTED_ARCH=$(uname -m)

    case "$DETECTED_OS" in
        Linux)   DETECTED_OS=linux ;;
        Darwin)  DETECTED_OS=darwin ;;
        *)       fail "unsupported OS: $DETECTED_OS (CE binaries are published for Linux and macOS)" ;;
    esac

    case "$DETECTED_ARCH" in
        x86_64|amd64)   DETECTED_ARCH=x86_64 ;;
        aarch64|arm64)  DETECTED_ARCH=aarch64 ;;
        *)              fail "unsupported architecture: $DETECTED_ARCH" ;;
    esac

    printf '%s-%s\n' "$DETECTED_OS" "$DETECTED_ARCH"
}

# perf-wave-10B: detect_gpu — pick between CPU and CUDA tarball variants.
#
# Sets DETECTED_GPU to "cpu" or "cuda". Override via SYNAPCORES_GPU env
# var:
#   SYNAPCORES_GPU=cpu  curl ... | sh   (force CPU even on a GPU host)
#   SYNAPCORES_GPU=cuda curl ... | sh   (skip detection, demand CUDA)
#
# CUDA variant is published only for linux-x86_64. macOS / aarch64
# always resolve to "cpu" — Apple Silicon uses Metal (separate codepath),
# and we don't ship aarch64 CUDA tarballs.
detect_gpu() {
    DETECTED_GPU=cpu

    # Allow explicit override before we run any detection.
    if [ -n "${SYNAPCORES_GPU:-}" ]; then
        DETECTED_GPU="$SYNAPCORES_GPU"
        log "GPU override: SYNAPCORES_GPU=${SYNAPCORES_GPU}"
        return
    fi

    # No CUDA build for macOS or for aarch64 — Apple uses Metal, and
    # we don't currently publish aarch64 CUDA tarballs.
    if [ "$DETECTED_OS" = "darwin" ]; then return; fi
    if [ "$DETECTED_ARCH" = "aarch64" ]; then return; fi

    # Primary signal: nvidia-smi works (driver is loaded + GPU visible).
    if command -v nvidia-smi >/dev/null 2>&1; then
        if nvidia-smi >/dev/null 2>&1; then
            DETECTED_GPU=cuda
            log "NVIDIA GPU detected via nvidia-smi"
            return
        fi
    fi

    # Fallback: libcuda.so.1 present (covers headless servers without
    # nvidia-smi installed but with the runtime driver lib in place).
    if [ -f /usr/lib/x86_64-linux-gnu/libcuda.so.1 ] \
       || [ -f /usr/lib64/libcuda.so.1 ] \
       || [ -f /usr/lib/libcuda.so.1 ]; then
        DETECTED_GPU=cuda
        log "CUDA runtime library (libcuda.so.1) detected"
        return
    fi

    log "No CUDA detected — using CPU build"
}

# detect_intel_mac_unsupported: bail out on Intel Macs (no native binary
# published). Split out from detect_platform() because POSIX `$(...)` runs
# the function in a subshell and `exit` from there only kills the subshell.
detect_intel_mac_unsupported() {
    # Intel Mac native binary is not published as of v1.3.0-ce. The
    # source migration to ffmpeg-next 7 unblocked the build, but
    # GitHub-hosted macos-13 runner availability has been unreliable
    # on personal-account repos (multi-hour queue waits with no
    # allocation). Apple Silicon (macos-14) builds reliably, so we
    # ship Apple Silicon native + recommend Docker for Intel Macs.
    if [ "$DETECTED_OS" = "darwin" ] && [ "$DETECTED_ARCH" = "x86_64" ]; then
        cat >&2 <<INTEL_MAC_EOF

[get-synapcores] Intel Mac (x86_64) native binaries are not currently
published. Apple Silicon (M1/M2/M3/M4) Macs have a native binary
available, but Intel Mac users should run via Docker:

  docker run -p 8080:8080 -v synapcores-data:/var/lib/synapcores \\
             -e AIDB_JWT_SECRET="\$(openssl rand -base64 32)" \\
             -e AIDB_ENCRYPTION_KEY="\$(openssl rand -base64 32)" \\
             ghcr.io/synapcores/community:latest

Apple discontinued Intel Macs in 2023 and the GitHub-hosted macos-13
runner pool is too small to reliably allocate. Native Intel Mac
binaries may return in a future release if runner availability
improves.

Full platform matrix: https://docs.synapcores.com/requirements/

INTEL_MAC_EOF
        exit 1
    fi
}

# check_distro: verify the host runs a supported Linux distribution
# BEFORE downloading 50 MB of binary that won't link, AND select the
# correct tarball variant via DISTRO_TAG.
#
# Two Linux tarball variants are published per architecture:
#   - linux-{x86_64,aarch64}          built on Ubuntu 22.04 (FFmpeg 4 SONAMEs)
#   - linux-{x86_64,aarch64}-ubuntu24 built on Ubuntu 24.04 (FFmpeg 6 SONAMEs)
#
# DISTRO_TAG is "" for the 22.04 variant and "-ubuntu24" for the 24.04
# variant. macOS sets DISTRO_TAG="" — the platform string already carries
# the OS distinction (darwin-x86_64, darwin-aarch64).
#
# https://docs.synapcores.com/requirements/#supported-linux-distributions
check_distro() {
    DISTRO_TAG=""
    if [ ! -f /etc/os-release ]; then
        warn "no /etc/os-release found; cannot verify distro compatibility"
        warn "if the install fails with a missing libavutil, see"
        warn "  https://docs.synapcores.com/requirements/"
        return 0
    fi
    # shellcheck disable=SC1091
    . /etc/os-release

    case "${ID:-unknown}:${VERSION_ID:-?}" in
        ubuntu:22.04)
            log "Distro: ${PRETTY_NAME:-$ID $VERSION_ID} — supported (FFmpeg 4 build)."
            DISTRO_TAG=""
            ;;
        ubuntu:24.04|debian:13)
            log "Distro: ${PRETTY_NAME:-$ID $VERSION_ID} — supported (FFmpeg 6 build)."
            DISTRO_TAG="-ubuntu24"
            ;;
        debian:12)
            # Debian 12 (bookworm) ships FFmpeg 5.1.x with libavutil.so.57.
            # Our Ubuntu 22.04 build is linked against libavutil.so.56
            # (FFmpeg 4); our Ubuntu 24.04 build is linked against
            # libavutil.so.58 (FFmpeg 6). Neither matches Debian 12.
            # Until v1.3.2 ships a Debian 12 native build, route Debian
            # 12 users to Docker (which bundles its own FFmpeg).
            cat >&2 <<DEBIAN12_EOF

[get-synapcores] Debian 12 (bookworm) is supported via Docker, not the native binary.

Reason: Debian 12 ships FFmpeg 5.1 (libavutil.so.57). The CE native
binary is built against either FFmpeg 4 (libavutil.so.56, Ubuntu 22.04)
or FFmpeg 6 (libavutil.so.58, Ubuntu 24.04). Neither matches Debian 12's
FFmpeg ABI, so the binary won't dynamically link.

Run via Docker:

  docker run -d --name synapcores -p 8080:8080 \\
             -v synapcores-data:/var/lib/synapcores \\
             -e AIDB_JWT_SECRET="\$(openssl rand -base64 32)" \\
             -e AIDB_ENCRYPTION_KEY="\$(openssl rand -base64 32)" \\
             ghcr.io/synapcores/community:latest

  docker logs -f synapcores | grep -A 7 FIRST-BOOT

A Debian 12 native build is queued for v1.3.2-ce. Until then the
Docker image is the supported path.

DEBIAN12_EOF
            exit 1
            ;;
        ubuntu:20.04|ubuntu:18.04|debian:11|debian:10)
            cat >&2 <<DISTRO_OLD_EOF

[get-synapcores] ${PRETTY_NAME:-$ID $VERSION_ID} is too old.

The CE binary requires glibc 2.35 (Ubuntu 22.04 / Debian 12 baseline).
Your system has glibc < 2.35 and the binary will not link.

Options:
  1. Upgrade to Ubuntu 22.04 LTS or Debian 12.
  2. Run via Docker (works on any Linux):
       docker run -p 8080:8080 -v synapcores-data:/var/lib/synapcores \\
                  -e AIDB_JWT_SECRET="\$(openssl rand -base64 32)" \\
                  -e AIDB_ENCRYPTION_KEY="\$(openssl rand -base64 32)" \\
                  ghcr.io/synapcores/community:latest

Full distro matrix: https://docs.synapcores.com/requirements/#supported-linux-distributions

DISTRO_OLD_EOF
            exit 1
            ;;
        ubuntu:24.10|ubuntu:25.04|debian:14)
            cat >&2 <<DISTRO_NEW_EOF

[get-synapcores] ${PRETTY_NAME:-$ID $VERSION_ID} is not yet in the verified support matrix.

The CE matrix currently ships binaries for:
  - Ubuntu 22.04 / Debian 12 (FFmpeg 4)
  - Ubuntu 24.04 / Debian 13 (FFmpeg 6)
  - macOS 13+ (Intel + Apple Silicon)

Workarounds:
  1. Run via Docker (works on any Linux):
       docker run -p 8080:8080 -v synapcores-data:/var/lib/synapcores \\
                  -e AIDB_JWT_SECRET="\$(openssl rand -base64 32)" \\
                  -e AIDB_ENCRYPTION_KEY="\$(openssl rand -base64 32)" \\
                  ghcr.io/synapcores/community:latest

  2. Use a supported distro in a VM or container.

Full distro matrix: https://docs.synapcores.com/requirements/#supported-linux-distributions

DISTRO_NEW_EOF
            exit 1
            ;;
        rhel:9*|rocky:9*|almalinux:9*|amzn:2023)
            warn "${PRETTY_NAME:-$ID $VERSION_ID}: untested but may work."
            warn "If the install fails on missing libraries, install:"
            warn "  sudo dnf install -y epel-release"
            warn "  sudo dnf install -y ffmpeg-libs tesseract leptonica freetype fontconfig"
            warn "Please report success/failure: https://github.com/SynapCores/synapcores-releases/issues"
            ;;
        rhel:8*|rocky:8*|almalinux:8*|centos:7*|amzn:2)
            cat >&2 <<DISTRO_RHEL_OLD_EOF

[get-synapcores] ${PRETTY_NAME:-$ID $VERSION_ID} has glibc < 2.35.

The CE binary will not link. Use Docker or upgrade to RHEL 9 / Rocky 9 /
Alma 9 / Amazon Linux 2023.

DISTRO_RHEL_OLD_EOF
            exit 1
            ;;
        alpine:*)
            cat >&2 <<ALPINE_EOF

[get-synapcores] Alpine Linux uses musl libc; the CE binary requires glibc.

Use the Docker image (which is glibc-based) instead:
  docker run -p 8080:8080 -v synapcores-data:/var/lib/synapcores \\
             -e AIDB_JWT_SECRET="\$(openssl rand -base64 32)" \\
             -e AIDB_ENCRYPTION_KEY="\$(openssl rand -base64 32)" \\
             ghcr.io/synapcores/community:latest

ALPINE_EOF
            exit 1
            ;;
        *)
            warn "Distro: ${PRETTY_NAME:-$ID $VERSION_ID} — not in the verified support matrix."
            warn "Continuing anyway with the FFmpeg 4 build. If the binary fails to link, see:"
            warn "  https://docs.synapcores.com/requirements/"
            ;;
    esac
}

PLATFORM=$(detect_platform)
log "Platform: $PLATFORM"

# Re-derive DETECTED_OS / DETECTED_ARCH in the parent shell. POSIX
# `$(...)` runs the function in a subshell, so the assignments inside
# detect_platform() never escape — and `set -eu` aborts the install
# script the first time it reads `$DETECTED_OS` later (real bug
# reported on a fresh Debian 12 install of v1.3.1-ce: "sh: 349:
# DETECTED_OS: parameter not set").
DETECTED_OS="${PLATFORM%-*}"
DETECTED_ARCH="${PLATFORM#*-}"

# Bail out on Intel Mac BEFORE we fingerprint the host any further —
# we don't ship a native binary for it. (Has to run in the parent
# shell so its `exit 1` actually terminates the script.)
detect_intel_mac_unsupported

# perf-wave-10B: pick CPU vs CUDA tarball variant. detect_gpu() reads
# the env override (SYNAPCORES_GPU={cpu,cuda}) first, then probes
# nvidia-smi / libcuda.so.1.
#
# Track whether the GPU choice was set explicitly so we know whether to
# offer the user an opt-out below. Env override = no prompt; auto-detect
# = prompt the operator on a tty (a developer with a GPU box may still
# want the smaller CPU build for a quick test of the default 1B model).
if [ -n "${SYNAPCORES_GPU:-}" ]; then
    GPU_AUTO_DETECTED=false
else
    GPU_AUTO_DETECTED=true
fi
detect_gpu
log "GPU: $DETECTED_GPU"

# Offer to fall back to the CPU build when CUDA was auto-detected.
# Skipped when:
#   - SYNAPCORES_GPU was set explicitly (operator already chose)
#   - SYNAPCORES_NONINTERACTIVE=1 (CI / automation)
#   - SYNAPCORES_BINARY_ONLY=1 (operator handling setup themselves)
#   - stdin is not a tty / no /dev/tty available
# Default answer = keep CUDA (preserves existing behavior).
if [ "$DETECTED_GPU" = "cuda" ] && [ "$GPU_AUTO_DETECTED" = "true" ] \
   && [ -z "${SYNAPCORES_NONINTERACTIVE:-}" ] && [ -z "$BINARY_ONLY" ] \
   && [ -e /dev/tty ]; then
    cat <<GPU_PROMPT
[get-synapcores] NVIDIA GPU detected. Which build would you like?

  1) CPU build   → smaller, no CUDA runtime deps. Fine for the
                   default Llama-3.2-1B and quick testing.
  2) CUDA build  → GPU-accelerated. Recommended for heavy LLM
                   workloads / larger models.

GPU_PROMPT
    printf '\033[1;34m[get-synapcores]\033[0m Choose [1/2] (default 2): '
    read -r GPU_ANSWER < /dev/tty || GPU_ANSWER="2"
    case "$GPU_ANSWER" in
        1|cpu|CPU)
            DETECTED_GPU=cpu
            log "Switched to CPU build (user choice)"
            ;;
        *)
            : # keep CUDA
            ;;
    esac
fi

# DISTRO_TAG is meaningful only for Linux. macOS skips check_distro.
DISTRO_TAG=""
case "$PLATFORM" in
    linux-*)
        check_distro
        ;;
esac

# ---------------------------------------------------------------------
# Resolve version
# ---------------------------------------------------------------------

# ---------------------------------------------------------------------
# Resolve install mode (system vs user)
# ---------------------------------------------------------------------
#
# Linux only. macOS already does a userland-style install (writes under
# ~/.synapcores) regardless, so the prompt only matters for Linux where
# the default is the sudo / /opt / systemd path.
#
# Honor SYNAPCORES_USER_INSTALL if set. Otherwise prompt when stdin is
# a tty and SYNAPCORES_NONINTERACTIVE is unset; default = system mode.
if [ "$DETECTED_OS" = "linux" ] && [ -z "$USER_INSTALL" ] \
   && [ -z "${SYNAPCORES_NONINTERACTIVE:-}" ] && [ -z "$BINARY_ONLY" ] \
   && [ -e /dev/tty ]; then
    cat <<MODE_PROMPT
[get-synapcores] How would you like to install?

  1) System install  → /opt/synapcores + /etc/systemd unit  (requires sudo)
                       Recommended for production / always-on use.
  2) User install    → ~/.local/bin + ~/.synapcores         (no sudo)
                       Good for quickly testing the application.
                       No system user, no service, foreground binary.

MODE_PROMPT
    printf '\033[1;34m[get-synapcores]\033[0m Choose [1/2] (default 1): '
    read -r MODE_ANSWER < /dev/tty || MODE_ANSWER="1"
    case "$MODE_ANSWER" in
        2|user|U|u) USER_INSTALL=1 ;;
        *)          USER_INSTALL="" ;;
    esac
fi

# Resolve INSTALL_PREFIX now that USER_INSTALL is settled.
if [ -z "$INSTALL_PREFIX" ]; then
    if [ -n "$USER_INSTALL" ]; then
        INSTALL_PREFIX="${HOME}/.local/bin"
    else
        INSTALL_PREFIX="/usr/local/bin"
    fi
fi

if [ -n "$USER_INSTALL" ]; then
    log "Install mode: user (binary → ${INSTALL_PREFIX}, no sudo)"
    # Make sure the binary dir exists. ~/.local/bin is the XDG default
    # and is on PATH on most modern distros via ~/.profile, but it's
    # not guaranteed to exist on a fresh user account.
    mkdir -p "$INSTALL_PREFIX"
else
    log "Install mode: system (binary → ${INSTALL_PREFIX}, requires sudo)"
fi

if [ -z "$PINNED_VERSION" ]; then
    log "Resolving latest release..."
    # IMPORTANT: no -L. With -L, curl follows the redirect and
    # %{redirect_url} comes back empty. We need GitHub's 302 Location
    # header (which points at /tag/<version>) to extract the tag.
    PINNED_VERSION=$(
        curl -fsS -o /dev/null -w '%{redirect_url}' "${RELEASE_BASE}/latest" \
            | sed 's@^.*/tag/@@'
    )
    [ -n "$PINNED_VERSION" ] || fail "could not resolve latest release"
fi
log "Version: $PINNED_VERSION"

# ---------------------------------------------------------------------
# Anonymous install counter ping (no PII, opt-out via COUNTER_OPT_OUT=1)
# ---------------------------------------------------------------------
# One fire-and-forget GET after platform + version are resolved and
# before the download starts. curl-pipe-sh leaves no trace on GitHub
# Pages, so this is the only way we can count CLI installs. Sends only
# the version tag, OS and arch (already public in the tarball URL).
# 5-second timeout; `|| true` means a down counter never blocks install.
if [ -z "${COUNTER_OPT_OUT:-}" ]; then
    _counter_url="https://synapcores.com/api/install-counter?v=${PINNED_VERSION}&os=${DETECTED_OS}&arch=${DETECTED_ARCH}&channel=cli"
    curl -fsSL --max-time 5 -o /dev/null "$_counter_url" 2>/dev/null || true
fi

# ---------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------

# DISTRO_TAG is "" on Ubuntu 22.04 / Debian 12 / macOS / unknown distros
# (FFmpeg 4 / native Mac tarball) and "-ubuntu24" on Ubuntu 24.04 / Debian 13
# (FFmpeg 6 tarball variant). Set by check_distro() above.
#
# perf-wave-10B: GPU_TAG is "-cuda" when DETECTED_GPU=cuda (libcuda
# present or explicit override) and "" otherwise. The CUDA variant is
# only published for linux-x86_64; detect_gpu() already short-circuits
# to "cpu" elsewhere, so this concat is safe everywhere.
GPU_TAG=""
if [ "$DETECTED_GPU" = "cuda" ]; then
    GPU_TAG="-cuda"

    # Not every release ships a CUDA tarball — the linux-x86_64-cuda
    # build OOM-kills the 16 GB GitHub-hosted runner during the LTO
    # link step (see release-ce.yml note on CARGO_PROFILE_RELEASE_LTO).
    # When the GPU choice was auto-detected, probe the release asset
    # before committing to the CUDA tarball; on 404, fall back to CPU.
    # An explicit SYNAPCORES_GPU=cuda override is honored — we let the
    # download fail loudly so the operator notices instead of silently
    # getting a CPU binary.
    if [ "$GPU_AUTO_DETECTED" = "true" ]; then
        CUDA_TARBALL="synapcores-ce-${PINNED_VERSION}-${PLATFORM}${DISTRO_TAG}-cuda.tar.gz"
        CUDA_URL="${RELEASE_BASE}/download/${PINNED_VERSION}/${CUDA_TARBALL}"
        if curl -sfI "$CUDA_URL" >/dev/null 2>&1; then
            log "CUDA tarball confirmed for ${PINNED_VERSION}"
        else
            warn "CUDA tarball not published for ${PINNED_VERSION} — falling back to CPU build"
            DETECTED_GPU=cpu
            GPU_TAG=""
        fi
    fi
fi
TARBALL="synapcores-ce-${PINNED_VERSION}-${PLATFORM}${DISTRO_TAG}${GPU_TAG}.tar.gz"
TARBALL_URL="${RELEASE_BASE}/download/${PINNED_VERSION}/${TARBALL}"
CHECKSUM_URL="${TARBALL_URL}.sha256"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT INT TERM

log "Downloading ${TARBALL}..."
curl -fsSL "$TARBALL_URL" -o "${WORK_DIR}/${TARBALL}" \
    || fail "download failed: $TARBALL_URL"

log "Downloading checksum..."
curl -fsSL "$CHECKSUM_URL" -o "${WORK_DIR}/${TARBALL}.sha256" \
    || fail "checksum download failed: $CHECKSUM_URL"

# ---------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------

log "Verifying checksum..."
(
    cd "$WORK_DIR"
    EXPECTED=$(awk '{print $1}' "${TARBALL}.sha256")
    ACTUAL=$($SHA256_TOOL "${TARBALL}" | awk '{print $1}')
    if [ "$EXPECTED" != "$ACTUAL" ]; then
        fail "checksum mismatch: expected $EXPECTED got $ACTUAL"
    fi
)
log "Checksum OK."

# ---------------------------------------------------------------------
# Extract
# ---------------------------------------------------------------------

log "Extracting..."
tar -xzf "${WORK_DIR}/${TARBALL}" -C "$WORK_DIR"

# The workflow packages the binary inside a single top-level dir:
#   synapcores-ce-<VERSION>-<PLATFORM>/synapcores
# Locate it without hardcoding the dir name so the script keeps
# working if the packaging convention changes.
BINARY_SRC=$(find "$WORK_DIR" -maxdepth 3 -type f -name synapcores -perm -u+x 2>/dev/null | head -1)
if [ -z "$BINARY_SRC" ] || [ ! -x "$BINARY_SRC" ]; then
    fail "extracted archive does not contain a 'synapcores' executable"
fi

# ---------------------------------------------------------------------
# Install binary
# ---------------------------------------------------------------------

# POSIX sh has no $EUID — use `id -u`. Also POSIX has no arrays, so we
# use SUDO_PREFIX as a (possibly empty) string that is word-split into
# argv when the install command runs.
#
# User mode never needs sudo — the binary lands in the user's own
# ~/.local/bin (or whatever they set via SYNAPCORES_PREFIX).
if [ -n "$USER_INSTALL" ] || [ "$(id -u)" -eq 0 ]; then
    SUDO_PREFIX=""
else
    log "Installing to ${INSTALL_PREFIX} requires sudo..."
    SUDO_PREFIX="sudo"
fi

# shellcheck disable=SC2086
$SUDO_PREFIX install -m 0755 "$BINARY_SRC" "${INSTALL_PREFIX}/synapcores" \
    || fail "binary install failed"
log "Installed: ${INSTALL_PREFIX}/synapcores"

# ONNX Runtime is loaded relative to the installed executable. Preserve it
# before WORK_DIR is deleted, including macOS, user and binary-only installs.
# Existing tarballs without an ONNX manifest keep their previous capability;
# a new manifest with missing runtime/attribution is a broken package.
ONNX_PACKAGE_DIR="$(dirname "$BINARY_SRC")"
if [ -f "${ONNX_PACKAGE_DIR}/onnx-runtime-manifest.json" ]; then
    case "$DETECTED_OS" in
        linux) ONNX_LIBRARY_NAME="libonnxruntime.so" ;;
        darwin) ONNX_LIBRARY_NAME="libonnxruntime.dylib" ;;
    esac
    ONNX_RUNTIME_DIR="${INSTALL_PREFIX}/lib/synapcores"
    ONNX_NOTICE_DIR="${INSTALL_PREFIX}/share/synapcores/licenses/onnxruntime"
    [ -r "${ONNX_PACKAGE_DIR}/lib/${ONNX_LIBRARY_NAME}" ] \
        || fail "ONNX package is missing ${ONNX_LIBRARY_NAME}"
    for ONNX_NOTICE in LICENSE ThirdPartyNotices.txt VERSION_NUMBER; do
        [ -r "${ONNX_PACKAGE_DIR}/licenses/onnxruntime/${ONNX_NOTICE}" ] \
            || fail "ONNX package is missing native attribution: ${ONNX_NOTICE}"
    done
    # shellcheck disable=SC2086
    $SUDO_PREFIX mkdir -p "$ONNX_RUNTIME_DIR" "$ONNX_NOTICE_DIR" \
        || fail "cannot create ONNX runtime install directories"
    # macOS loader dependencies/symlink targets travel as one runtime folder.
    if [ "$DETECTED_OS" = darwin ]; then
        $SUDO_PREFIX cp -R "${ONNX_PACKAGE_DIR}/lib/." "$ONNX_RUNTIME_DIR/" \
            || fail "macOS runtime folder install failed"
    fi
    for ONNX_LIBRARY in "${ONNX_PACKAGE_DIR}"/lib/libonnxruntime*.so* "${ONNX_PACKAGE_DIR}"/lib/libonnxruntime*.dylib; do
        [ -f "$ONNX_LIBRARY" ] || continue
        # shellcheck disable=SC2086
        $SUDO_PREFIX install -m 0644 "$ONNX_LIBRARY" "${ONNX_RUNTIME_DIR}/$(basename "$ONNX_LIBRARY")" \
            || fail "ONNX runtime library install failed"
    done
    for ONNX_NOTICE in LICENSE ThirdPartyNotices.txt VERSION_NUMBER; do
        # shellcheck disable=SC2086
        $SUDO_PREFIX install -m 0644 "${ONNX_PACKAGE_DIR}/licenses/onnxruntime/${ONNX_NOTICE}" "${ONNX_NOTICE_DIR}/${ONNX_NOTICE}" \
            || fail "ONNX runtime attribution install failed"
    done
    # shellcheck disable=SC2086
    $SUDO_PREFIX install -m 0644 "${ONNX_PACKAGE_DIR}/onnx-runtime-manifest.json" "${ONNX_RUNTIME_DIR}/onnx-runtime-manifest.json" \
        || fail "ONNX runtime provenance install failed"
    log "Installed CPU ONNX runtime: ${ONNX_RUNTIME_DIR}/${ONNX_LIBRARY_NAME}"
fi

# The checksum-verified package carries the platform startup helper. It is
# installed beside the executable for relocatable foreground/launchd/systemd use.
START_HELPER_SRC="${ONNX_PACKAGE_DIR}/synapcores-start.sh"
if [ -f "$START_HELPER_SRC" ]; then
    $SUDO_PREFIX install -m 0755 "$START_HELPER_SRC" "${INSTALL_PREFIX}/synapcores-start" \
        || fail "startup helper install failed"
fi

# In user mode, warn if the install dir isn't on PATH. ~/.local/bin is
# included by ~/.profile on most modern distros, but only after the
# next login — so a fresh-from-`useradd` account might not see it yet.
if [ -n "$USER_INSTALL" ]; then
    case ":${PATH}:" in
        *":${INSTALL_PREFIX}:"*)
            : # already on PATH
            ;;
        *)
            warn "${INSTALL_PREFIX} is not on your PATH for this shell."
            warn "Run synapcores via its full path, or add to your shell rc:"
            warn "  export PATH=\"${INSTALL_PREFIX}:\$PATH\""
            ;;
    esac
fi

# ---------------------------------------------------------------------
# Verify install (deferred on both OSes)
# ---------------------------------------------------------------------
#
# Skipped here intentionally. The CE binary is dynamically linked
# against FFmpeg / Tesseract / Leptonica that aren't installed yet —
#   - macOS: Homebrew may not have them installed
#   - Linux: install-ce.sh runs apt-get for them next
# So `synapcores --version` would fail with "error while loading
# shared libraries: libavutil.so.56" on a fresh box and the
# resulting "binary did not report 'Community'" warning would mislead
# the operator into thinking the wrong edition was downloaded.
# install-ce.sh does the version check AFTER its install_runtime_deps
# step, which is the right point.

# ---------------------------------------------------------------------
# System setup (or skip)
# ---------------------------------------------------------------------

if [ -n "$BINARY_ONLY" ]; then
    log "SYNAPCORES_BINARY_ONLY set; skipping system setup."
    exit 0
fi

# macOS path: detect missing Homebrew deps and offer to install them.
# install-ce.sh is a Linux installer (useradd, apt-get, systemd) and
# would fail with "useradd: command not found" on macOS — we don't
# call it here.
#
# The CE macOS binary is dynamically linked against Homebrew's
# ffmpeg, tesseract, and leptonica. Without them the binary's
# dynamic linker fails silently and `--version` returns nothing.
#
# Set SYNAPCORES_NONINTERACTIVE=1 to skip the prompt and install
# missing deps automatically (CI / automation).
if [ "$DETECTED_OS" = "darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
        warn "Homebrew is required for macOS runtime deps (ffmpeg/tesseract/leptonica)."
        warn "Install Homebrew first:  https://brew.sh"
        warn "Then re-run:  curl -fsSL https://get.synapcores.com/install.sh | sh"
        exit 1
    fi

    # Pick the right ffmpeg formula. We try ffmpeg@7 first because
    # that's what the GitHub Actions release built against; if it's
    # not in the user's Homebrew tap we fall back to plain ffmpeg
    # (ffmpeg-next 7 supports both 7.x and 8.x at runtime).
    if brew info ffmpeg@7 >/dev/null 2>&1; then
        FFMPEG_FORMULA="ffmpeg@7"
    else
        FFMPEG_FORMULA="ffmpeg"
    fi
    REQUIRED_DEPS="$FFMPEG_FORMULA tesseract leptonica"

    MISSING_DEPS=""
    for dep in $REQUIRED_DEPS; do
        if ! brew list --formula "$dep" >/dev/null 2>&1; then
            MISSING_DEPS="$MISSING_DEPS $dep"
        fi
    done
    # Strip leading whitespace
    MISSING_DEPS=$(printf '%s' "$MISSING_DEPS" | sed 's/^ *//')

    if [ -n "$MISSING_DEPS" ]; then
        log "Missing Homebrew deps: $MISSING_DEPS"

        if [ -n "${SYNAPCORES_NONINTERACTIVE:-}" ]; then
            log "Non-interactive mode (SYNAPCORES_NONINTERACTIVE set); installing..."
            ANSWER="y"
        elif [ ! -t 0 ] && [ ! -e /dev/tty ]; then
            warn "stdin is not a terminal and /dev/tty is unavailable; cannot prompt."
            warn "Install manually:  brew install $MISSING_DEPS"
            warn "Or set SYNAPCORES_NONINTERACTIVE=1 to install automatically."
            exit 1
        else
            printf '\033[1;34m[get-synapcores]\033[0m Install them now? (brew install %s) [Y/n] ' "$MISSING_DEPS"
            # Read from /dev/tty so the prompt works under
            # `curl ... | sh` where stdin is the script itself.
            read -r ANSWER < /dev/tty || ANSWER="n"
        fi

        case "$ANSWER" in
            ""|[Yy]*)
                log "Running: brew install $MISSING_DEPS"
                # shellcheck disable=SC2086
                brew install $MISSING_DEPS || {
                    warn "brew install failed. Install manually:  brew install $MISSING_DEPS"
                    exit 1
                }
                ;;
            *)
                log "Skipping. Install manually:  brew install $MISSING_DEPS"
                log "Then run:  ${INSTALL_PREFIX}/synapcores --version"
                exit 0
                ;;
        esac
    else
        log "All Homebrew runtime deps present."
    fi

    # With deps installed, the binary should now run.
    if "${INSTALL_PREFIX}/synapcores" --version 2>/dev/null | grep -q "Community"; then
        log "Edition check: $("${INSTALL_PREFIX}/synapcores" --version)"
    else
        warn "Binary still won't run cleanly. Diagnose with:"
        warn "  otool -L ${INSTALL_PREFIX}/synapcores | head -20"
        warn "Look for any 'not found' lines pointing at missing dylibs."
    fi

    # ----- Drop default config + data dir -----
    SC_HOME="${HOME}/.synapcores"
    SC_CONFIG="${SC_HOME}/gateway.toml"
    SC_DATA_DIR="${AIDB_DATA_DIR:-${SC_HOME}/data}"
    case "$SC_DATA_DIR" in
        /*) ;;
        *) fail "AIDB_DATA_DIR must be an absolute path for installation" ;;
    esac
    SC_MODELS_DIR="${SC_HOME}/models/text"

    mkdir -p "$SC_HOME" "$SC_DATA_DIR" "$SC_MODELS_DIR"
    chmod 700 "$SC_HOME"
    START_HELPER="${INSTALL_PREFIX}/synapcores-start"
    [ -x "$START_HELPER" ] || fail "release is missing synapcores-start.sh; install a complete current release folder"

    # The bundled template (v1.3.1+) lives next to the binary in the
    # extracted tarball. Older tarballs don't have it, so fall through
    # to the inline minimal config in that case.
    BUNDLED_TEMPLATE="$(dirname "$BINARY_SRC")/community.toml.template"

    if [ -f "$SC_CONFIG" ]; then
        log "Config already exists at ${SC_CONFIG} — leaving as-is."
    elif [ -f "$BUNDLED_TEMPLATE" ]; then
        # Adapt the template for macOS: rewrite the data_dir to live
        # under the user's home (the template defaults to
        # /opt/synapcores/aidb_data, which would need root and isn't
        # the macOS convention).
        SC_DATA_TOML=$(printf %s "$SC_DATA_DIR" | sed 's/\\/\\\\/g; s/"/\\"/g')
        while IFS= read -r template_line || [ -n "$template_line" ]; do
            case "$template_line" in
                data_dir\ =*) printf 'data_dir = "%s"\n' "$SC_DATA_TOML" ;;
                *) printf '%s\n' "$template_line" ;;
            esac
        done < "$BUNDLED_TEMPLATE" > "$SC_CONFIG"
        log "Wrote default config to ${SC_CONFIG}"
    else
        warn "No config template bundled (older tarball?). Generating minimal config."
        SC_DATA_TOML=$(printf %s "$SC_DATA_DIR" | sed 's/\\/\\\\/g; s/"/\\"/g')
        cat >"$SC_CONFIG" <<MIN_CFG
data_dir = "${SC_DATA_TOML}"
[server]
listen_addr     = "127.0.0.1:8080"
max_body_size   = 1073741824
# Seconds, at the HTTP layer. 30 cuts the connection before a cold GENERATE
# (~2 min on CPU) can answer, which defeats default_timeout_ms on its own.
# The Docker image has used 300 for this reason.
request_timeout = 300
enable_cors     = true

[auth]
enabled          = true
token_expiration = 86400

[query]
max_concurrent_queries = 32
# 5 minutes, matching the engine's own default. This template used to write
# 30000 (30 s) — the value the engine deliberately moved AWAY from in v1.6.5 —
# so every install that followed this file got a stricter timeout than an
# install with no config at all. On a CPU-only host a cold GENERATE takes ~2
# minutes, so LLM-backed SQL (GENERATE, AGENT_RUN, NL2SQL) failed with
# "Operation timeout" out of the box. OLTP callers that want fail-fast should
# lower this deliberately rather than inherit it by accident.
default_timeout_ms     = 300000

[query.ai_service]
provider        = "local"
model           = "qwen2.5-coder:7b"
embedding_model = "all-minilm:latest"
auto_pull       = true

[ai_cache]
enabled              = false
similarity_threshold = 0.92
ttl_seconds          = 3600
max_entries          = 10000
embedding_dim        = 384
MIN_CFG
        log "Wrote minimal config to ${SC_CONFIG}"
    fi

    # Use the engine's own resolver for existing custom data_dir configurations.
    SC_DATA_DIR="$("${INSTALL_PREFIX}/synapcores" --config "$SC_CONFIG" models data-dir)" \
        || fail "Cannot resolve the configured data directory"
    mkdir -p "$SC_DATA_DIR"

    # ----- Offer to pre-pull the default model from the native registry -----
    #
    # v1.8.x ships its own OCI registry client that pulls GGUF + chat
    # template + params blobs from registry.ollama.ai into the data
    # dir's content-addressed store. The gateway.toml above sets
    # auto_pull = true so first-use works regardless — pre-pulling
    # just front-loads the ~4.4 GB download into the install step.
    DEFAULT_MODEL="qwen2.5-coder:7b"
    INSTALLED_BIN="${INSTALL_PREFIX}/synapcores"

    # Existing models belong to the operator. Upgrades never delete legacy
    # GGUFs or imported bundles; migrations can retain their explicit paths.

    if [ ! -x "$INSTALLED_BIN" ]; then
        warn "installed binary not found at ${INSTALLED_BIN}; skipping pre-pull."
        warn "warm-on-boot + auto_pull = true in gateway.toml will pull on first start."
    elif [ -n "${SYNAPCORES_NO_MODEL_DOWNLOAD:-}" ]; then
        log "SYNAPCORES_NO_MODEL_DOWNLOAD set; skipping pre-pull."
        log "warm-on-boot + auto_pull = true in gateway.toml will pull on first start."
    else
        if [ -n "${SYNAPCORES_NONINTERACTIVE:-}" ]; then
            log "Non-interactive: pre-pulling default LLM..."
            DL_ANSWER="y"
        elif [ ! -t 0 ] && [ ! -e /dev/tty ]; then
            warn "Cannot prompt for LLM pre-pull (no tty). Skipping."
            warn "Pull manually later:  ${INSTALLED_BIN} pull ${DEFAULT_MODEL}"
            DL_ANSWER="n"
        else
            printf '\033[1;34m[get-synapcores]\033[0m Pre-pull default LLM (qwen2.5-coder:7b, ~4.4GB) from registry.ollama.ai? [Y/n] '
            read -r DL_ANSWER < /dev/tty || DL_ANSWER="n"
        fi

        case "$DL_ANSWER" in
            ""|[Yy]*)
                log "Running: ${INSTALLED_BIN} pull ${DEFAULT_MODEL}"
                if AIDB_DATA_DIR="$SC_DATA_DIR" "$INSTALLED_BIN" --config "$SC_CONFIG" pull "$DEFAULT_MODEL"; then
                    log "  ✓ ${DEFAULT_MODEL} pulled into the registry blob store"
                else
                    warn "pull failed; the gateway's auto_pull will retry on first use."
                fi
                ;;
            *)
                log "Skipped. The engine will pull on first use (auto_pull = true). To pre-pull later:"
                log "  ${INSTALLED_BIN} pull ${DEFAULT_MODEL}"
                log "Or edit ${SC_CONFIG} [query.ai_service] to switch to OpenAI / Anthropic / Ollama."
                ;;
        esac
    fi

    if [ -z "${SYNAPCORES_WITH_NLI:-}" ] && [ -t 0 ] && [ -e /dev/tty ] \
        && [ -z "${SYNAPCORES_NONINTERACTIVE:-}" ]; then
        printf '\033[1;34m[get-synapcores]\033[0m Enable semantic verification (NLI, ~577 MB)? [y/N] '
        read -r NLI_ANSWER < /dev/tty || NLI_ANSWER=n
        case "$NLI_ANSWER" in [Yy]*) NLI_OPT_IN=1 ;; esac
    fi
    if [ "$NLI_OPT_IN" = 1 ]; then
        log "Installing semantic verification (${NLI_MODEL})..."
        if [ -z "${SYNAPCORES_NO_MODEL_DOWNLOAD:-}" ]; then
            AIDB_DATA_DIR="$SC_DATA_DIR" "$INSTALLED_BIN" --config "$SC_CONFIG" pull "$NLI_MODEL" \
                || fail "NLI download failed; re-run with SYNAPCORES_WITH_NLI=1 to resume"
        fi
        AIDB_DATA_DIR="$SC_DATA_DIR" "$INSTALLED_BIN" --config "$SC_CONFIG" models enable-nli "$NLI_MODEL" \
            || fail "NLI requires a complete installed/imported bundle"
        log "NLI enabled. Start/restart the gateway; GET /v1/ai/nli/models reports actual readiness."
    fi

    # Add only missing settings; keep existing secrets/model/runtime choices.
    # The launchd agent invokes the helper, which reads this private file on
    # every launch. Secret values are never copied into the XML or logs.
    SC_ENV_FILE="${SC_HOME}/synapcores.env"
    "$START_HELPER" --prepare-env --env-file "$SC_ENV_FILE" \
        --models-dir "$SC_MODELS_DIR" \
        --runtime "${INSTALL_PREFIX}/lib/synapcores/libonnxruntime.dylib" \
        || fail "could not prepare private runtime environment"
    SC_PLIST="${HOME}/Library/LaunchAgents/com.synapcores.gateway.plist"
    "$START_HELPER" --write-launchd --binary "$INSTALLED_BIN" --config "$SC_CONFIG" \
        --env-file "$SC_ENV_FILE" --plist "$SC_PLIST" \
        || fail "could not prepare launchd agent"
    log "Prepared private environment and launchd agent; no service was loaded or started."

    cat <<MAC_FINISH_EOF

[get-synapcores] Done — start the gateway

  "${START_HELPER}" --env-file "${SC_ENV_FILE}" --binary "${INSTALLED_BIN}" --config "${SC_CONFIG}"

The first start prints an admin password — capture it from the log
output. Then open the Web UI at http://localhost:8080/

(Optional) start the prepared launchd agent:
  launchctl bootstrap "gui/$(id -u)" "${SC_PLIST}"
  launchctl print "gui/$(id -u)/com.synapcores.gateway"

A fatal start stops without an automatic restart loop. Inspect private logs under
${SC_HOME}/logs, fix the error, then start again deliberately. The helper checks
configured HTTP/HTTPS ports before launching; it never stops their current owner.

MAC_FINISH_EOF
    exit 0
fi

# Linux path: fetch and run install-ce.sh.
#   - System mode: needs sudo. Creates synapcores user, /opt/synapcores
#     layout, systemd unit at /etc/systemd/system/.
#   - User mode:   no sudo. ~/.synapcores layout, no system user, no
#     systemd unit (foreground binary).
# install-ce.sh is allowed to use bash — it's saved to disk first, so
# its shebang is honored. Only THIS bootstrap has to be POSIX-clean.
INSTALLER_URL="${RELEASE_BASE}/download/${PINNED_VERSION}/install-ce.sh"
INSTALLER="${WORK_DIR}/install-ce.sh"

log "Fetching system installer..."
if curl -fsSL "$INSTALLER_URL" -o "$INSTALLER" 2>/dev/null; then
    chmod +x "$INSTALLER"
    set -- "$INSTALLER" --binary "${INSTALL_PREFIX}/synapcores"
    if [ "$NLI_OPT_IN" = 1 ]; then
        set -- "$@" --with-nli --nli-model "$NLI_MODEL"
    fi
    if [ -n "$USER_INSTALL" ]; then
        log "Running install-ce.sh --user (no sudo)..."
        set -- "$@" --user
    fi
    # Pass only installer controls across sudo; do not forward the caller's
    # unrelated environment. The model itself is pulled by the service user.
    set -- env "SYNAPCORES_WITH_NLI=${SYNAPCORES_WITH_NLI:-}" \
        "SYNAPCORES_NO_MODEL_DOWNLOAD=${SYNAPCORES_NO_MODEL_DOWNLOAD:-}" \
        "SYNAPCORES_NONINTERACTIVE=${SYNAPCORES_NONINTERACTIVE:-}" "$@"
    if [ -n "${AIDB_DATA_DIR:-}" ]; then
        set -- env "AIDB_DATA_DIR=$AIDB_DATA_DIR" "$@"
    fi
    if [ -n "$USER_INSTALL" ] || [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        log "System setup requires sudo..."
        sudo "$@"
    fi
else
    warn "system installer not found at $INSTALLER_URL"
    warn "binary is installed; complete setup manually per the docs"
fi

log "Done. Try: synapcores --version"
