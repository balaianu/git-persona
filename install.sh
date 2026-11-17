#!/bin/bash

# install.sh: One-liner installer for git-persona
# Usage: curl -fsSL https://raw.githubusercontent.com/balaianu/git-persona/main/install.sh | bash
# Pin a release: GIT_PERSONA_REF=vX.Y.Z bash install.sh

set -euo pipefail

REPO="balaianu/git-persona"
REF="${GIT_PERSONA_REF:-main}"
INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_NAME="git-persona"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}==>${NC} $1"; }
warn()  { echo -e "${YELLOW}==> WARNING:${NC} $1"; }
error() { echo -e "${RED}==> ERROR:${NC} $1"; exit 1; }

# Detect download tool
if command -v curl >/dev/null 2>&1; then
    FETCH="curl -fsSL"
elif command -v wget >/dev/null 2>&1; then
    FETCH="wget -qO-"
else
    error "Neither curl nor wget is installed. Please install one and try again."
fi

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download to a temp file first so an interrupted download or a failed check
# never replaces a working install.
TMP="$(mktemp "${INSTALL_DIR}/.${SCRIPT_NAME}.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

info "Downloading git-persona (${REF})..."
URL="https://raw.githubusercontent.com/${REPO}/${REF}/src/${SCRIPT_NAME}"
$FETCH "$URL" > "$TMP" || error "Failed to download from $URL"

if ! bash -n "$TMP" 2>/dev/null || ! head -n 1 "$TMP" | grep -q '^#!.*bash'; then
    error "Downloaded script failed verification. Installation aborted; existing install left untouched."
fi

chmod +x "$TMP"
mv "$TMP" "${INSTALL_DIR}/${SCRIPT_NAME}"

# Check PATH
case ":${PATH}:" in
    *":${INSTALL_DIR}:"*)
        info "Installed to ${INSTALL_DIR}/${SCRIPT_NAME}"
        info "Version: $(${INSTALL_DIR}/${SCRIPT_NAME} version)"
        info "Try it: git persona help"
        ;;
    *)
        warn "${INSTALL_DIR} is not in your PATH."
        warn "Add this line to your ~/.bashrc or ~/.zshrc:"
        echo ""
        echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
        echo ""
        info "Then run: source ~/.bashrc"
        ;;
esac
