#!/bin/bash
set -e

echo "=== 1. Setup ==="
sudo apt-get update
sudo apt-get install -y wget unzip zip jq

echo "=== 2. Download & Extract ==="
if [ -z "$ROM_URL" ]; then
    echo "Error: ROM_URL is not set."
    exit 1
fi
echo "Downloading ROM from $ROM_URL"
wget -q --show-progress "$ROM_URL" -O downloaded_rom.zip

mkdir -p rom_workspace
unzip -q downloaded_rom.zip -d rom_workspace/

echo "=== 3. Download Payload ==="
wget -q "https://github.com/topjohnwu/Magisk/releases/download/v30.7/Magisk-v30.7.apk" -O rom_workspace/magisk_v30.zip

echo "=== 4. Clean up ==="
if [ -f rom_workspace/superuser.zip ]; then
    rm rom_workspace/superuser.zip
fi

echo "=== 5. JSON Bypass ==="
if [ -f rom_workspace/manifest.json ]; then
    jq '.su_uri = "" | .magisk_uri = "magisk_v30.zip"' rom_workspace/manifest.json > rom_workspace/manifest_tmp.json
    mv rom_workspace/manifest_tmp.json rom_workspace/manifest.json
else
    echo "Error: manifest.json not found in the ROM."
    exit 1
fi

echo "=== 6. Repack ==="
cd rom_workspace
zip -r9q ../VirtualMaster_Magisk_v30.zip .
cd ..

echo "=== 7. Upload ==="
echo "VirtualMaster_Magisk_v30.zip created successfully."
