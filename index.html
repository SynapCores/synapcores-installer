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
        Darwin)
            cat >&2 <<'MAC_EOF'

[get-synapcores] macOS native binaries aren't shipped in this release.

Two well-supported options run CE on macOS today:

  1. Multipass (lightweight Ubuntu VM, recommended):

       brew install --cask multipass
       multipass launch 22.04 --name synapcores --memory 8G --cpus 4 --disk 20G
       multipass shell synapcores
       # then inside the VM:
       curl -fsSL https://get.synapcores.com/install.sh | sh

  2. Docker (if you already have Docker Desktop):

       docker run -p 8080:8080 -v synapcores-data:/var/lib/synapcores \
                  -e AIDB_JWT_SECRET="$(openssl rand -base64 32)" \
                  ghcr.io/synapcores/community:latest

Full walkthrough including port forwarding and admin-password capture:

  https://docs.synapcores.com/macos/

Native macOS binaries will return in v1.1 once aidb-multimedia migrates
to the FFmpeg 5+ API.

MAC_EOF
            exit 1
            ;;
        *)       fail "unsupported OS: $DETECTED_OS (CE binaries are published for Linux only)" ;;
    esac

    case "$DETECTED_ARCH" in
        x86_64|amd64)   DETECTED_ARCH=x86_64 ;;
        aarch64|arm64)  DETECTED_ARCH=aarch64 ;;
        *)              fail "unsupported architecture: $DETECTED_ARCH" ;;
    esac

    printf '%s-%s\n' "$DETECTED_OS" "$DETECTED_ARCH"
}

PLATFORM=$(detect_platform)
log "Platform: $PLATFORM"

# ---------------------------------------------------------------------
# Resolve version
# ---------------------------------------------------------------------

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
# Download
# ---------------------------------------------------------------------

TARBALL="synapcores-ce-${PINNED_VERSION}-${PLATFORM}.tar.gz"
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
if [ "$(id -u)" -eq 0 ]; then
    SUDO_PREFIX=""
else
    log "Installing to ${INSTALL_PREFIX} requires sudo..."
    SUDO_PREFIX="sudo"
fi

# shellcheck disable=SC2086
$SUDO_PREFIX install -m 0755 "$BINARY_SRC" "${INSTALL_PREFIX}/synapcores" \
    || fail "binary install failed"
log "Installed: ${INSTALL_PREFIX}/synapcores"

# ---------------------------------------------------------------------
# Verify install
# ---------------------------------------------------------------------

if "${INSTALL_PREFIX}/synapcores" --version 2>/dev/null | grep -q "Community"; then
    log "Edition check: $("${INSTALL_PREFIX}/synapcores" --version)"
else
    warn "binary installed but did not report 'Community' on --version"
fi

# ---------------------------------------------------------------------
# System setup (or skip)
# ---------------------------------------------------------------------

if [ -n "$BINARY_ONLY" ]; then
    log "SYNAPCORES_BINARY_ONLY set; skipping system setup."
    log "To finish setup later: sudo ${INSTALL_PREFIX}/synapcores-installer"
    exit 0
fi

# Fetch the system installer from the same release. install-ce.sh is
# allowed to use bash — it's saved to disk first, so its shebang is
# honored. Only THIS bootstrap has to be POSIX-clean.
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
