#!/bin/bash
# Packs the three builds with the samples into dist/.
# Needs build/SolidCraft2000 (./build.sh), build/arm/SolidCraft2000
# (./build-arm.sh) and build/win/SolidCraft2000.exe (Lazarus on Windows).
set -e
cd "$(dirname "$0")"
V=1.2
D=dist/SolidCraft2000-Delphi-$V
rm -rf dist && mkdir -p "$D/Samples"
cp build/SolidCraft2000 "$D/sc2000-x86_64"
cp build/arm/SolidCraft2000 "$D/sc2000-pi"
cp build/win/SolidCraft2000.exe "$D/SolidCraft2000.exe"
sed 's/$/\r/' dist-readme.txt > "$D/README.TXT"
cp ../samples/*.sc2 "../samples/Mounting Plate.sc98" ../samples/*.solidcraft "$D/Samples/"
cp ../LICENSE ../NOTICE "$D/"
(cd dist && zip -qr "SolidCraft2000-Delphi-$V.zip" "SolidCraft2000-Delphi-$V")
ls -la dist/*.zip "$D"
