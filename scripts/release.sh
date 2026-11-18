#!/bin/zsh
# Starts the Release workflow on GitHub, which checks the version, builds and publishes it.
#   scripts/release.sh v1.0.0
set -euo pipefail

TAG="${1:?usage: scripts/release.sh vX.Y.Z}"
[[ "$TAG" == v<->.<->.<-> ]] || { echo "Version must look like v1.2.3" >&2; exit 1; }
gh workflow run release.yml --repo noyex/nxpaper --ref main -f version="$TAG"
echo "Started the release of $TAG: gh run watch --repo noyex/nxpaper"
