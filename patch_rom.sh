#!/bin/bash

# Exit on any error
set -e

echo "=== 1. Environment & Download ==="
# Ensure dependencies are installed
sudo apt-get update
sudo apt-get install -y wget unzip zip file tree

# Download Magisk v30.7 APK
echo "Downloading Magisk v30.7..."
wget -q --show-progress "https://github.com/topjohnwu/Magisk/releases/download/v30.7/Magisk-v30.7.apk" -O magisk.apk

echo "=== 2. Dynamic Main Zip Handling & Extraction ==="
# Dynamically find the downloaded ROM zip
# Exclude magisk.apk and any previously generated files
MAIN_ZIP=$(ls *.zip | grep -v magisk.apk | grep -v VirtualMaster_Rooted_Final.zip | head -n 1)

if [ -z "$MAIN_ZIP" ]; then
    echo "Error: Main ROM zip not found!"
    exit 1
fi

echo "Found main ROM zip: $MAIN_ZIP"

# Extract main ROM into main_extracted/
mkdir -p main_extracted
unzip -q "$MAIN_ZIP" -d main_extracted/

echo "=== 3. Nested ROM Extraction ==="
# Locate rom.zip inside main_extracted and extract it
if [ ! -f main_extracted/rom.zip ]; then
    echo "Error: rom.zip not found inside $MAIN_ZIP!"
    exit 1
fi

mkdir -p rom_extracted
unzip -q main_extracted/rom.zip -d rom_extracted/

echo "=== 4. Headless CLI Patching ==="
# Setup Magisk patching environment
mkdir -p magisk_patch_env
unzip -q magisk.apk -d magisk_patch_env/

# For headless patching on Linux (x86_64 runner) targeting arm64 ROM:
# 1. We need magiskboot (host binary) -> lib/x86_64/libmagiskboot.so
# 2. We need target magisk binaries (arm64) -> lib/arm64-v8a/libmagisk64.so, lib/armeabi-v7a/libmagisk32.so, lib/arm64-v8a/libmagiskinit.so
# 3. We need boot_patch.sh -> assets/boot_patch.sh

WORK_DIR="$(pwd)/magisk_work"
mkdir -p "$WORK_DIR"

# Copy necessary files for patching
cp magisk_patch_env/assets/boot_patch.sh "$WORK_DIR/"
cp magisk_patch_env/assets/stub.apk "$WORK_DIR/" 2>/dev/null || true

# Rename libmagiskboot.so to magiskboot and make executable
cp magisk_patch_env/lib/x86_64/libmagiskboot.so "$WORK_DIR/magiskboot"
chmod +x "$WORK_DIR/magiskboot"

# Rename target architecture binaries
cp magisk_patch_env/lib/arm64-v8a/libmagisk64.so "$WORK_DIR/magisk64"
cp magisk_patch_env/lib/armeabi-v7a/libmagisk32.so "$WORK_DIR/magisk32"
cp magisk_patch_env/lib/arm64-v8a/libmagiskinit.so "$WORK_DIR/magiskinit"

chmod +x "$WORK_DIR"/*

# Export environment variables for headless patching
export KEEPVERITY=false
export KEEPFORCEENCRYPT=false

# Prepare target boot.img
if [ ! -f rom_extracted/boot.img ]; then
    echo "Error: boot.img not found in rom_extracted!"
    exit 1
fi

cp rom_extracted/boot.img "$WORK_DIR/"

# Execute the headless patch
cd "$WORK_DIR"
echo "Running boot_patch.sh..."
# boot_patch.sh syntax: ./boot_patch.sh <boot.img>
sh boot_patch.sh boot.img
cd ..

# Verify patch success
if [ ! -f "$WORK_DIR/new-boot.img" ]; then
    echo "Error: Patching failed. new-boot.img not generated!"
    exit 1
fi

echo "Patching successful."

# Replace the original boot.img
cp "$WORK_DIR/new-boot.img" rom_extracted/boot.img

echo "=== 5. Repack Nested ROM ==="
# Repack rom_extracted back into rom.zip
cd rom_extracted
# The zip command updates or creates rom.zip with contents of the current directory
zip -r9q ../main_extracted/rom.zip .
cd ..

echo "=== 6. Repack Main ROM ==="
# Repack main_extracted into VirtualMaster_Rooted_Final.zip
cd main_extracted
zip -r9q ../VirtualMaster_Rooted_Final.zip .
cd ..

echo "=== Done ==="
echo "Successfully created VirtualMaster_Rooted_Final.zip"
