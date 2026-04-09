#!/bin/bash

# Hentikan script jika ada error
set -e

echo "=== 1. Environment & Download ==="
sudo apt-get update
sudo apt-get install -y wget unzip zip file tree

echo "Downloading Magisk v30.7..."
wget -q "https://github.com/topjohnwu/Magisk/releases/download/v30.7/Magisk-v30.7.apk" -O magisk.apk

echo "=== 2. Ekstrak Main Zip ==="
# Cari file utama secara dinamis
MAIN_ZIP=$(ls *.zip | grep -v 'magisk.apk' | grep -v 'VirtualMaster_Rooted_Final.zip' | head -n 1)

if [ -z "$MAIN_ZIP" ]; then
    echo "Error: Main ROM zip tidak ditemukan!"
    exit 1
fi
echo "Memproses file: $MAIN_ZIP"

mkdir -p main_extracted
unzip -q "$MAIN_ZIP" -d main_extracted/

echo "=== 3. Smart Scan: Mencari boot.img ==="
NESTED_MODE=false
BOOT_IMG_PATH=""

# Skenario A: Coba cari langsung di hasil ekstrak utama (Flat Structure)
BOOT_IMG_PATH=$(find main_extracted -name "boot.img" | head -n 1)

# Skenario B: Kalau tidak ketemu, cek apakah ada rom.zip (Nested Structure)
if [ -z "$BOOT_IMG_PATH" ]; then
    if [ -f "main_extracted/rom.zip" ]; then
        echo "Ditemukan rom.zip, mencoba ekstrak file bersarang..."
        mkdir -p rom_extracted
        unzip -q main_extracted/rom.zip -d rom_extracted/
        
        # Cari lagi boot.img di dalam hasil ekstrak rom.zip
        BOOT_IMG_PATH=$(find rom_extracted -name "boot.img" | head -n 1)
        NESTED_MODE=true
    fi
fi

# Validasi akhir pencarian
if [ -z "$BOOT_IMG_PATH" ]; then
    echo "Error: boot.img benar-benar tidak ditemukan di manapun!"
    exit 1
fi
echo "Sukses: boot.img ditemukan di -> $BOOT_IMG_PATH"

echo "=== 4. Setup Headless Patching ==="
mkdir -p magisk_patch_env
unzip -q magisk.apk -d magisk_patch_env/

WORK_DIR="$(pwd)/magisk_work"
mkdir -p "$WORK_DIR"

# Persiapkan script dan binary Magisk
cp magisk_patch_env/assets/boot_patch.sh "$WORK_DIR/"
cp magisk_patch_env/assets/stub.apk "$WORK_DIR/" 2>/dev/null || true
cp magisk_patch_env/lib/x86_64/libmagiskboot.so "$WORK_DIR/magiskboot"
cp magisk_patch_env/lib/arm64-v8a/libmagisk64.so "$WORK_DIR/magisk64"
cp magisk_patch_env/lib/armeabi-v7a/libmagisk32.so "$WORK_DIR/magisk32"
cp magisk_patch_env/lib/arm64-v8a/libmagiskinit.so "$WORK_DIR/magiskinit"
chmod +x "$WORK_DIR"/*

export KEEPVERITY=false
export KEEPFORCEENCRYPT=false

echo "=== 5. Eksekusi Patch Magisk ==="
# Copy boot.img yang ditemukan ke folder kerja
cp "$BOOT_IMG_PATH" "$WORK_DIR/boot.img"

cd "$WORK_DIR"
sh boot_patch.sh boot.img
cd ..

if [ ! -f "$WORK_DIR/new-boot.img" ]; then
    echo "Error: Patching Magisk gagal. new-boot.img tidak tercipta!"
    exit 1
fi
echo "Patching boot.img sukses!"

echo "=== 6. Smart Repack ==="
# Timpa boot.img asli dengan yang sudah ter-patch
cp "$WORK_DIR/new-boot.img" "$BOOT_IMG_PATH"

# Jika tadi kita mengekstrak rom.zip, kita harus zip ulang
if [ "$NESTED_MODE" = true ]; then
    echo "Repacking rom.zip bersarang..."
    cd rom_extracted
    zip -r9q ../main_extracted/rom.zip .
    cd ..
    # Hapus folder sementara agar tidak dobel
    rm -rf rom_extracted
else
    echo "Struktur Flat terdeteksi, melewati repack rom.zip..."
fi

# Bungkus semuanya kembali ke file final
echo "Repacking VirtualMaster_Rooted_Final.zip..."
cd main_extracted
zip -r9q ../VirtualMaster_Rooted_Final.zip .
cd ..

echo "=== 7. SELESAI ==="
echo "Artifact VirtualMaster_Rooted_Final.zip siap diunggah!"
