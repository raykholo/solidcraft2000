#!/bin/bash
# Builds build/SolidCraft2000 (x86-64 Linux) in the sc2000-lz-x86 image.
# Usage: build.sh [Debug]   (Debug: range checks and line numbers)
set -e
cd "$(dirname "$0")"
mode=${1:+--build-mode=$1}
podman run --rm -v "$PWD":/w:Z -w /w sc2000-lz-x86 lazbuild -q $mode SolidCraft2000.lpi
ls -la build/SolidCraft2000
