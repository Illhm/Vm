#!/bin/bash

# Hentikan script jika ada error
set -e

echo "=== Extracting ROM ==="
mkdir -p rom_extracted
unzip -q rom.zip -d rom_extracted/

cd rom_extracted

echo "=== Inspecting manifest.json ==="
if [ -f "manifest.json" ]; then
    cat manifest.json
else
    echo "manifest.json not found!"
fi

echo "=== Inspecting superuser.zip ==="
if [ -f "superuser.zip" ]; then
    unzip -l superuser.zip
else
    echo "superuser.zip not found!"
fi

echo "=== Inspecting rom.img ==="
if [ -f "rom.img" ]; then
    file rom.img
else
    echo "rom.img not found!"
fi

echo "=== Inspecting rom1.img ==="
if [ -f "rom1.img" ]; then
    file rom1.img
else
    echo "rom1.img not found!"
fi

echo "=== Listing all files ==="
ls -la

cd ..
echo "=== Done ==="
