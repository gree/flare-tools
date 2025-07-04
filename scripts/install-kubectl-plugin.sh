#!/bin/bash
# Install kubectl-flare plugin locally

set -e

echo "Installing kubectl-flare plugin..."

# Build the plugin
echo "Building kubectl-flare..."
go build -o kubectl-flare ./cmd/kubectl-flare

# Determine the kubectl plugin directory
PLUGIN_DIR="${HOME}/.kube/plugins/flare"
mkdir -p "${PLUGIN_DIR}"

# Copy the binary
cp kubectl-flare "${PLUGIN_DIR}/kubectl-flare"
chmod +x "${PLUGIN_DIR}/kubectl-flare"

# Create a symlink in a directory that's in PATH
# First, check if ~/.local/bin exists and is in PATH
if [[ -d "${HOME}/.local/bin" ]] && [[ ":$PATH:" == *":${HOME}/.local/bin:"* ]]; then
    INSTALL_DIR="${HOME}/.local/bin"
else
    # Otherwise use /usr/local/bin
    INSTALL_DIR="/usr/local/bin"
    echo "Note: Installing to ${INSTALL_DIR} may require sudo"
fi

# Install the plugin
if [[ -w "${INSTALL_DIR}" ]]; then
    ln -sf "${PLUGIN_DIR}/kubectl-flare" "${INSTALL_DIR}/kubectl-flare"
else
    echo "Installing to ${INSTALL_DIR} requires sudo privileges"
    sudo ln -sf "${PLUGIN_DIR}/kubectl-flare" "${INSTALL_DIR}/kubectl-flare"
fi

echo "kubectl-flare plugin installed successfully!"
echo ""
echo "Usage examples:"
echo "  kubectl flare admin list"
echo "  kubectl flare stats nodes"
echo "  kubectl flare admin ping server1:12121"
echo ""
echo "To specify a different namespace or pod selector:"
echo "  kubectl flare -n my-namespace admin list"
echo "  kubectl flare --pod-selector=app=my-flare-index admin list"