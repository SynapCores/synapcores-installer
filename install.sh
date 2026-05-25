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
# Or, to pin a specific release:
#   curl -fsSL https://get.synapcores.com/install.sh | SYNAPCORES_VERSION=v1.2.0 sh
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
#   5. Drops the binary at /usr/local/bin/synapcores (or asks if non-root)
#   6. Hands off to install-ce.sh for system setup (user, paths,
#      systemd unit, default config), unless SYNAPCORES_BINARY_ONLY is set
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
INSTALL_PREFIX="${SYNAPCORES_PREFIX:-/usr/local/bin}"
BINARY_ONLY="${SYNAPCORES_BINARY_ONLY:-}"

# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------

log()   { printf '\033[1;34m[get-synapcores]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[get-synapcores]\033[0m %s\n' "$*" >&2; }
fail()  { printf '\033[1;31m[get-synapcores]\033[0m %s\n' "$*" >&2; exit 1; }

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
             synapcores/community:latest

             # Behind a proxy / CI / rate-limited? use this one instead:
             ghcr.io/synapcores/community:latest

Apple discontinued Intel Macs in 2023 and the GitHub-hosted macos-13
runner pool is too small to reliably allocate. Native Intel Mac
binaries may return in a future release if runner availability
improves.

Full platform matrix: https://docs.synapcores.com/requirements/

INTEL_MAC_EOF
        exit 1
    fi

    printf '%s-%s\n' "$DETECTED_OS" "$DETECTED_ARCH"
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
             synapcores/community:latest

             # Behind a proxy / CI / rate-limited? use this one instead:
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
                  synapcores/community:latest

                  # Behind a proxy / CI / rate-limited? use this one instead:
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
                  synapcores/community:latest

                  # Behind a proxy / CI / rate-limited? use this one instead:
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
             synapcores/community:latest

             # Behind a proxy / CI / rate-limited? use this one instead:
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

AUTO_RESOLVED=0
if [ -z "$PINNED_VERSION" ]; then
    AUTO_RESOLVED=1
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
# Download
# ---------------------------------------------------------------------

# DISTRO_TAG is "" on Ubuntu 22.04 / Debian 12 / macOS / unknown distros
# (FFmpeg 4 / native Mac tarball) and "-ubuntu24" on Ubuntu 24.04 / Debian 13
# (FFmpeg 6 tarball variant). Set by check_distro() above.
TARBALL="synapcores-ce-${PINNED_VERSION}-${PLATFORM}${DISTRO_TAG}.tar.gz"
TARBALL_URL="${RELEASE_BASE}/download/${PINNED_VERSION}/${TARBALL}"
CHECKSUM_URL="${TARBALL_URL}.sha256"

# "alias to latest available": GitHub's release `latest` is global, not
# per-platform. If the resolved latest release has no binary for THIS platform
# (e.g. a Linux-only release), fall back to the newest release that does — so
# Mac/ARM users always get the latest *available* build instead of a 404.
# Only when the version was auto-resolved; a pinned $SYNAPCORES_VERSION fails loud.
asset_exists() { curl -fsSL -r 0-0 -o /dev/null "$1" 2>/dev/null; }
if [ "$AUTO_RESOLVED" = "1" ] && ! asset_exists "$TARBALL_URL"; then
    warn "No ${PLATFORM}${DISTRO_TAG} binary in ${PINNED_VERSION}; finding the latest release that has one..."
    _found=0
    _tags=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases?per_page=20" 2>/dev/null \
              | grep '"tag_name":' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')
    for _t in $_tags; do
        _cand="synapcores-ce-${_t}-${PLATFORM}${DISTRO_TAG}.tar.gz"
        _url="${RELEASE_BASE}/download/${_t}/${_cand}"
        if asset_exists "$_url"; then
            log "Using ${_t} — latest release with a ${PLATFORM}${DISTRO_TAG} binary."
            PINNED_VERSION="$_t"
            TARBALL="$_cand"
            TARBALL_URL="$_url"
            CHECKSUM_URL="${_url}.sha256"
            _found=1
            break
        fi
    done
    [ "$_found" = "1" ] || fail "no ${PLATFORM}${DISTRO_TAG} binary in recent releases — run via Docker instead: docker run -d -p 8080:8080 synapcores/community:latest"
fi

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

# v1.6.4.1 fix: on Apple Silicon Macs /usr/local/bin doesn't exist by
# default (Homebrew lives at /opt/homebrew/bin there). When the user
# hasn't pinned SYNAPCORES_PREFIX, prefer the Homebrew bin dir if
# it's present so the binary lands inside the user's existing $PATH.
# Falls back to /usr/local/bin only if Homebrew isn't there. Intel
# Macs and Linux keep the original /usr/local/bin default since
# that's where their Homebrew lives too (Intel) or always exists
# (most Linux distros).
if [ -z "${SYNAPCORES_PREFIX:-}" ] \
   && [ "$DETECTED_OS" = "darwin" ] \
   && [ "$DETECTED_ARCH" = "aarch64" ] \
   && [ -d /opt/homebrew/bin ]; then
    INSTALL_PREFIX="/opt/homebrew/bin"
    log "Apple Silicon detected with Homebrew; using ${INSTALL_PREFIX}"
fi

# POSIX sh has no $EUID — use `id -u`. Also POSIX has no arrays, so we
# use SUDO_PREFIX as a (possibly empty) string that is word-split into
# argv when the install command runs.
if [ "$(id -u)" -eq 0 ]; then
    SUDO_PREFIX=""
else
    log "Installing to ${INSTALL_PREFIX} requires sudo..."
    SUDO_PREFIX="sudo"
fi

# v1.6.4.1 fix: ensure the install directory exists before invoking
# install(1). On a fresh Apple Silicon Mac /usr/local/bin doesn't exist
# yet, which made BSD install fail with the cryptic
#   "install: /usr/local/bin/INS@<random>: No such file or directory"
# error — INS@* is the BSD-install atomic-rename tempfile, and it
# can't be created in a directory that doesn't exist.
# shellcheck disable=SC2086
$SUDO_PREFIX mkdir -p "$INSTALL_PREFIX" \
    || fail "could not create ${INSTALL_PREFIX} (need write or sudo)"

# shellcheck disable=SC2086
$SUDO_PREFIX install -m 0755 "$BINARY_SRC" "${INSTALL_PREFIX}/synapcores" \
    || fail "binary install failed"
log "Installed: ${INSTALL_PREFIX}/synapcores"

# v1.6.4.1: surface the PATH hint when we installed somewhere that
# isn't already on the user's PATH. Saves the next 60 seconds of
# "synapcores: command not found" frustration.
case ":${PATH}:" in
    *":${INSTALL_PREFIX}:"*) ;; # already on PATH
    *)
        cat >&2 <<PATH_HINT_EOF

[get-synapcores] ${INSTALL_PREFIX} is not on your \$PATH. Add it
with:

    export PATH="${INSTALL_PREFIX}:\$PATH"

(append the same line to ~/.zshrc or ~/.bashrc to make it permanent).
PATH_HINT_EOF
        ;;
esac

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
    SC_DATA_DIR="${SC_HOME}/data"
    SC_MODELS_DIR="${SC_HOME}/models/text"

    mkdir -p "$SC_HOME" "$SC_DATA_DIR" "$SC_MODELS_DIR"

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
        sed "s|^data_dir = .*|data_dir = \"${SC_DATA_DIR}\"|" \
            "$BUNDLED_TEMPLATE" \
            > "$SC_CONFIG"
        log "Wrote default config to ${SC_CONFIG}"
    else
        warn "No config template bundled (older tarball?). Generating minimal config."
        cat >"$SC_CONFIG" <<MIN_CFG
[server]
listen_addr     = "127.0.0.1:8080"
max_body_size   = 1073741824
request_timeout = 30
enable_cors     = true
data_dir = "${SC_DATA_DIR}"

[auth]
enabled          = true
token_expiration = 86400

[query]
max_concurrent_queries = 32
default_timeout_ms     = 30000

[query.ai_service]
provider        = "native"
model           = "llama-3.2-1b-instruct-q4_k_m"
embedding_model = "minilm"

[ai_cache]
enabled              = false
similarity_threshold = 0.92
ttl_seconds          = 3600
max_entries          = 10000
embedding_dim        = 384
MIN_CFG
        log "Wrote minimal config to ${SC_CONFIG}"
    fi

    # ----- Offer to download the default LLM (GGUF) -----
    DEFAULT_MODEL_FILE="${SC_MODELS_DIR}/llama-3.2-1b-instruct-q4_k_m.gguf"
    DEFAULT_MODEL_URL="https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf"

    if [ -f "$DEFAULT_MODEL_FILE" ]; then
        log "Default LLM already at ${DEFAULT_MODEL_FILE}"
    elif [ -n "${SYNAPCORES_NO_MODEL_DOWNLOAD:-}" ]; then
        log "SYNAPCORES_NO_MODEL_DOWNLOAD set; skipping LLM download."
        log "AI Chat will fall back to whichever provider is enabled in the config."
    else
        if [ -n "${SYNAPCORES_NONINTERACTIVE:-}" ]; then
            log "Non-interactive: downloading default LLM..."
            DL_ANSWER="y"
        elif [ ! -t 0 ] && [ ! -e /dev/tty ]; then
            warn "Cannot prompt for LLM download (no tty). Skipping."
            warn "Download manually:  curl -L -o ${DEFAULT_MODEL_FILE} ${DEFAULT_MODEL_URL}"
            DL_ANSWER="n"
        else
            printf '\033[1;34m[get-synapcores]\033[0m Download default LLM (Llama 3.2 1B Q4_K_M, ~700MB)? [Y/n] '
            read -r DL_ANSWER < /dev/tty || DL_ANSWER="n"
        fi

        case "$DL_ANSWER" in
            ""|[Yy]*)
                log "Downloading ${DEFAULT_MODEL_URL}"
                log "  → ${DEFAULT_MODEL_FILE}"
                if curl -fL --progress-bar -o "${DEFAULT_MODEL_FILE}.tmp" "$DEFAULT_MODEL_URL"; then
                    mv "${DEFAULT_MODEL_FILE}.tmp" "$DEFAULT_MODEL_FILE"
                    log "  ✓ downloaded $(du -h "$DEFAULT_MODEL_FILE" | cut -f1)"
                else
                    warn "Download failed. Skip and retry later via:"
                    warn "  curl -L -o ${DEFAULT_MODEL_FILE} ${DEFAULT_MODEL_URL}"
                    rm -f "${DEFAULT_MODEL_FILE}.tmp"
                fi
                ;;
            *)
                log "Skipped. Download manually any time:"
                log "  curl -L -o ${DEFAULT_MODEL_FILE} ${DEFAULT_MODEL_URL}"
                log "Or edit ${SC_CONFIG} to change [query.ai_service] provider."
                ;;
        esac
    fi

    # The native provider uses AIDB_MODELS_DIR to locate GGUF files.
    # Hard-code the path users shouldn't have to discover.
    SC_MODELS_DIR_ABS="$SC_MODELS_DIR"

    cat <<MAC_FINISH_EOF

[get-synapcores] Done — start the gateway

  export AIDB_JWT_SECRET="\$(openssl rand -base64 32)"
  export AIDB_MODELS_DIR="${SC_MODELS_DIR_ABS}"
  ${INSTALL_PREFIX}/synapcores --config ${SC_CONFIG}

The first start prints an admin password — capture it from the log
output. Then open the Web UI at http://localhost:8080/

(Optional) auto-start via launchd:
  https://docs.synapcores.com/macos/#launchd-setup

MAC_FINISH_EOF
    exit 0
fi

# Linux path: fetch and run install-ce.sh (creates synapcores user,
# /opt/synapcores layout, systemd unit). install-ce.sh is allowed to
# use bash — it's saved to disk first, so its shebang is honored. Only
# THIS bootstrap has to be POSIX-clean.
INSTALLER_URL="${RELEASE_BASE}/download/${PINNED_VERSION}/install-ce.sh"
INSTALLER="${WORK_DIR}/install-ce.sh"

log "Fetching system installer..."
if curl -fsSL "$INSTALLER_URL" -o "$INSTALLER" 2>/dev/null; then
    chmod +x "$INSTALLER"
    if [ "$(id -u)" -eq 0 ]; then
        "$INSTALLER" --binary "${INSTALL_PREFIX}/synapcores"
    else
        log "System setup requires sudo..."
        sudo "$INSTALLER" --binary "${INSTALL_PREFIX}/synapcores"
    fi
else
    warn "system installer not found at $INSTALLER_URL"
    warn "binary is installed; complete setup manually per the docs"
fi

log "Done. Try: synapcores --version"
