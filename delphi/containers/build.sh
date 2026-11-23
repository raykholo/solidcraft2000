#!/bin/bash
# Builds the two images the scripts use: sc2000-lz-x86 and sc2000-lz-arm.
# Usage: containers/build.sh [x86|arm]   (both if not given)
set -e
cd "$(dirname "$0")"
want=${1:-all}
if [ "$want" = all ] || [ "$want" = x86 ]; then podman build -t sc2000-lz-x86 x86; fi
if [ "$want" = all ] || [ "$want" = arm ]; then podman build --platform linux/arm/v6 -t sc2000-lz-arm arm; fi
