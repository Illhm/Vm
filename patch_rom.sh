#!/bin/bash

# Hentikan script jika ada error
set -e

echo "=== 1. Environment & Download ==="
sudo apt-get update
# Memastikan dependensi terinstal (guestfish dan tools lainnya dihapus karena menggunakan bypass JSON)
sudo apt-get install -y wget unzip zip file tree jq

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
# Menggunakan -o agar tidak memunculkan prompt replace file
unzip -o -q "$MAIN_ZIP" -d main_extracted/

echo "=== 3. Smart Scan: Mencari rom.img / manifest.json ==="
NESTED_MODE=false
WORKSPACE="main_extracted"

# Skenario A: Coba cari apakah ini nested (ada rom.zip di dalam)
if [ -f "main_extracted/rom.zip" ]; then
    echo "Ditemukan rom.zip, mencoba ekstrak file bersarang..."
    mkdir -p rom_extracted
    unzip -o -q main_extracted/rom.zip -d rom_extracted/
    WORKSPACE="rom_extracted"
    NESTED_MODE=true
fi

echo "=== 4. JSON Bypass & Cleanup ==="
# Hapus superuser.zip jika ada
if [ -f "$WORKSPACE/superuser.zip" ]; then
    echo "Menghapus superuser.zip yang usang/corrupt..."
    rm "$WORKSPACE/superuser.zip"
fi

# Salin magisk.apk ke dalam workspace ROM
echo "Menyalin magisk.apk ke dalam ROM..."
cp magisk.apk "$WORKSPACE/"

if [ -f "$WORKSPACE/manifest.json" ]; then
    echo "Modifikasi manifest.json..."
    jq '.su_uri = "" | .magisk_uri = "magisk.apk"' "$WORKSPACE/manifest.json" > "$WORKSPACE/manifest_tmp.json"
    mv "$WORKSPACE/manifest_tmp.json" "$WORKSPACE/manifest.json"
    cat "$WORKSPACE/manifest.json"
else
    echo "Error: manifest.json tidak ditemukan di $WORKSPACE!"
    exit 1
fi

echo "=== 5. Smart Repack ==="
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

echo "=== 6. SELESAI ==="
echo "Artifact VirtualMaster_Rooted_Final.zip siap diunggah!"
