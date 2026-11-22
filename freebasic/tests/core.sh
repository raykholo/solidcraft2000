#!/bin/bash
# Builds and runs tests/core_test.bas in the x86-64 image (the model and the geometry, no screen).
# It reads ../samples, so the whole repository is mounted.
cd "$(dirname "$0")/.."
mkdir -p tests/out
podman run --rm -v "$PWD/..":/r:Z -w /r/freebasic sc2000-fb-x86 bash -c "fbc -w all tests/core_test.bas -x build/core_test 2>&1 | grep -v 'warning 38'; build/core_test"
