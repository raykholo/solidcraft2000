#!/bin/bash
# Builds both programs and packs them with the samples into dist/.
set -e
cd "$(dirname "$0")"
# --pack-only: pack build/sc2000 and build/arm/sc2000 as they are (CI builds them)
if [ "$1" != --pack-only ]; then
  ./build.sh src/sc2000.bas build/sc2000 2>&1 | grep -v "warning 38" || true
  podman run --rm -v "$PWD":/w:Z -w /w sc98-fb-x86 strip build/sc2000
  ./build-arm.sh > /dev/null
fi
V=1.2
D=dist/SolidCraft98-Linux-$V
rm -rf dist && mkdir -p "$D/Samples"
cp build/sc2000 "$D/sc98-x86_64"
cp build/arm/sc2000 "$D/sc98-pi"
cp dist-readme.txt "$D/README.TXT"
cp "tests/Mounting Plate.sc98" tests/*.solidcraft "$D/Samples/"
cp ../LICENSE ../NOTICE "$D/"
tar -C dist -czf "dist/SolidCraft98-Linux-$V.tar.gz" "SolidCraft98-Linux-$V"
ls -la dist/*.tar.gz "$D"
