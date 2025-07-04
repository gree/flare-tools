#!/bin/bash
# Build debian package for flare-tools using Docker

set -e

echo "Building flare-tools debian package..."

# Build using Docker
docker build --platform=linux/amd64 -f Dockerfile.debian -t flare-tools-debian .

# Extract the .deb file
docker run --rm --platform=linux/amd64 -v $(pwd):/host flare-tools-debian \
    cp /flare-tools_1.0.0-1_amd64.deb /host/

echo "Package built: flare-tools_1.0.0-1_amd64.deb"