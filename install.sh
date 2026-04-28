#!/usr/bin/env bash
#
# get-synapcores-ce.sh — one-line remote installer for SynapCores
# Community Edition.
#
# Hosted at: https://get.synapcores.com (or your CDN-fronted equivalent
# pointing at this script in the GitHub repo).
#
# Usage:
#   curl -fsSL https://get.synapcores.com | sh
#
# Or, to pin a specific release:
#   curl -fsSL https://get.synapcores.com | SYNAPCORES_VERSION=v1.2.0 sh
#
# What it does:
#   1. Detects the OS and architecture
#   2. Resolves the latest GitHub release tag (or honors $SYNAPCORES_VERSION)
#   3. Downloads the matching binary tarball + checksum
#   4. Verifies the checksum
#   5. Drops the binary at /usr/local/bin/synapcores (or asks if non-root)
#   6. Hands off to install-ce.sh for system setup (user, paths,
#      systemd unit, default config), unless --binary-only is passed
#
# Requirements:
#   - curl
#   - tar
#   - sha256sum (or shasum -a 256)
#   - bash 4+

set -euo pipefail

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

detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux)   os="linux" ;;
        Darwin)
            cat >&2 <<'MAC_EOF'

[get-synapcores] macOS native binaries aren't shipped in this release.

CE on macOS is supported via Docker. Run the official image:

  docker run -p 8080:8080 -v synapcores-data:/var/lib/synapcores \
             ghcr.io/synapcores/community:latest

Or build the binary from source if you have FFmpeg < 5 installed:

  git clone <source-repo> && cargo build --release -p aidb-gateway

Native macOS binaries will return in v1.1 once aidb-multimedia migrates
to the FFmpeg 5+ API. Track progress at https://github.com/SynapCores.

MAC_EOF
            exit 1
            ;;
        *)       fail "unsupported OS: $os (CE binaries are published for Linux only)" ;;
    esac

    case "$arch" in
        x86_64|amd64)   arch="x86_64" ;;
        aarch64|arm64)  arch="aarch64" ;;
        *)              fail "unsupported architecture: $arch" ;;
    esac

    echo "${os}-${arch}"
}

PLATFORM="$(detect_platform)"
log "Platform: $PLATFORM"

# ---------------------------------------------------------------------
# Resolve version
# ---------------------------------------------------------------------

if [[ -z "$PINNED_VERSION" ]]; then
    log "Resolving latest release..."
    PINNED_VERSION="$(
        curl -fsSL -o /dev/null -w '%{redirect_url}' "${RELEASE_BASE}/latest" \
            | sed 's@^.*/tag/@@'
    )"
    [[ -n "$PINNED_VERSION" ]] || fail "could not resolve latest release"
fi
log "Version: $PINNED_VERSION"

# ---------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------

TARBALL="synapcores-ce-${PINNED_VERSION}-${PLATFORM}.tar.gz"
TARBALL_URL="${RELEASE_BASE}/download/${PINNED_VERSION}/${TARBALL}"
CHECKSUM_URL="${TARBALL_URL}.sha256"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

log "Downloading ${TARBALL}..."
curl -fsSL "$TARBALL_URL" -o "${TMPDIR}/${TARBALL}" \
    || fail "download failed: $TARBALL_URL"

log "Downloading checksum..."
curl -fsSL "$CHECKSUM_URL" -o "${TMPDIR}/${TARBALL}.sha256" \
    || fail "checksum download failed: $CHECKSUM_URL"

# ---------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------

log "Verifying checksum..."
(
    cd "$TMPDIR"
    EXPECTED="$(awk '{print $1}' "${TARBALL}.sha256")"
    ACTUAL="$($SHA256_TOOL "${TARBALL}" | awk '{print $1}')"
    if [[ "$EXPECTED" != "$ACTUAL" ]]; then
        fail "checksum mismatch: expected $EXPECTED got $ACTUAL"
    fi
)
log "Checksum OK."

# ---------------------------------------------------------------------
# Extract
# ---------------------------------------------------------------------

log "Extracting..."
tar -xzf "${TMPDIR}/${TARBALL}" -C "$TMPDIR"

BINARY_SRC="${TMPDIR}/synapcores"
[[ -x "$BINARY_SRC" ]] || fail "extracted archive does not contain 'synapcores' binary"

# ---------------------------------------------------------------------
# Install binary
# ---------------------------------------------------------------------

if [[ "$EUID" -eq 0 ]]; then
    INSTALL_CMD=(install -m 0755 "$BINARY_SRC" "${INSTALL_PREFIX}/synapcores")
else
    log "Installing to ${INSTALL_PREFIX} requires sudo..."
    INSTALL_CMD=(sudo install -m 0755 "$BINARY_SRC" "${INSTALL_PREFIX}/synapcores")
fi

"${INSTALL_CMD[@]}" || fail "binary install failed"
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

if [[ -n "$BINARY_ONLY" ]]; then
    log "SYNAPCORES_BINARY_ONLY set; skipping system setup."
    log "To finish setup later: sudo ${INSTALL_PREFIX}/synapcores-installer"
    exit 0
fi

# Fetch the system installer from the same release
INSTALLER_URL="${RELEASE_BASE}/download/${PINNED_VERSION}/install-ce.sh"
INSTALLER="${TMPDIR}/install-ce.sh"

log "Fetching system installer..."
if curl -fsSL "$INSTALLER_URL" -o "$INSTALLER" 2>/dev/null; then
    chmod +x "$INSTALLER"
    if [[ "$EUID" -eq 0 ]]; then
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
