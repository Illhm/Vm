#!/bin/bash

# Hentikan script jika ada error
set -e

echo "=== 1. Environment & Download ==="
sudo apt-get update
#<<<<<<< fix-virtual-master-rom-magisk-injection-12963882449561167965
sudo apt-get install -y wget unzip zip file tree libguestfs-tools linux-image-generic
=======
# Ditambahkan android-sdk-libsparse-utils untuk simg2img dan img2simg
sudo apt-get install -y wget unzip zip file tree libguestfs-tools linux-image-generic android-sdk-libsparse-utils
#>>>>>>> main

export LIBGUESTFS_BACKEND=direct
sudo chmod 0644 /boot/vmlinuz-* || true

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

echo "=== 3. Smart Scan: Mencari rom.img ==="
NESTED_MODE=false
ROM_IMG_PATH=""

# Skenario A: Coba cari langsung di hasil ekstrak utama (Flat Structure)
ROM_IMG_PATH=$(find main_extracted -name "rom.img" | head -n 1)

# Skenario B: Kalau tidak ketemu, cek apakah ada rom.zip (Nested Structure)
if [ -z "$ROM_IMG_PATH" ]; then
    if [ -f "main_extracted/rom.zip" ]; then
        echo "Ditemukan rom.zip, mencoba ekstrak file bersarang..."
        mkdir -p rom_extracted
        unzip -q main_extracted/rom.zip -d rom_extracted/
        
        # Cari lagi rom.img di dalam hasil ekstrak rom.zip
        ROM_IMG_PATH=$(find rom_extracted -name "rom.img" | head -n 1)
        NESTED_MODE=true
    fi
fi

# Validasi akhir pencarian
if [ -z "$ROM_IMG_PATH" ]; then
    echo "Error: rom.img benar-benar tidak ditemukan di manapun!"
    exit 1
fi
echo "Sukses: rom.img ditemukan di -> $ROM_IMG_PATH"

echo "=== 4. Setup Headless Patching ==="
mkdir -p magisk_patch_env
#<<<<<<< fix-virtual-master-rom-magisk-injection-12963882449561167965
# Unzip libmagisk64.so or its equivalent (libmagisk.so)
unzip -q magisk.apk "lib/arm64-v8a/libmagisk*.so" -d magisk_patch_env/
#=======
unzip -q magisk.apk lib/arm64-v8a/libmagisk.so -d magisk_patch_env/
#>>>>>>> main

WORK_DIR="$(pwd)/magisk_work"
mkdir -p "$WORK_DIR"

# Persiapkan script dan binary Magisk
#<<<<<<< fix-virtual-master-rom-magisk-injection-12963882449561167965
if [ -f "magisk_patch_env/lib/arm64-v8a/libmagisk64.so" ]; then
    cp magisk_patch_env/lib/arm64-v8a/libmagisk64.so "$WORK_DIR/magisk"
else
    cp magisk_patch_env/lib/arm64-v8a/libmagisk.so "$WORK_DIR/magisk"
fi
chmod +x "$WORK_DIR"/*

#=======
cp magisk_patch_env/lib/arm64-v8a/libmagisk.so "$WORK_DIR/magisk"
chmod +x "$WORK_DIR"/*

echo "=== 4.5. Konversi Image (Sparse ke Raw) ==="
IS_SPARSE=false
# Cek apakah file adalah Android Sparse Image
if file "$ROM_IMG_PATH" | grep -qi "sparse"; then
    echo "Terdeteksi Android Sparse Image! Mengonversi ke Raw ext4..."
    simg2img "$ROM_IMG_PATH" "${ROM_IMG_PATH}.raw"
    
    # Ganti file lama dengan yang raw
    rm "$ROM_IMG_PATH"
    mv "${ROM_IMG_PATH}.raw" "$ROM_IMG_PATH"
    
    IS_SPARSE=true
else
    echo "Bukan Sparse Image. Melanjutkan..."
fi

#>>>>>>> main
echo "=== 5. Eksekusi Patch Magisk (Direct Injection) ==="

cat << 'EOF' > "$WORK_DIR/magisk.rc"
on post-fs-data
    start magiskd
service magiskd /system/bin/magisk --daemon
    class core
    user root
    oneshot
EOF

# Dynamically determine the correct Android system bin path
SYS_BIN=$(guestfish -a "$ROM_IMG_PATH" -m /dev/sda is-dir /system/bin)
if [ "$SYS_BIN" = "true" ]; then
    TARGET_BIN="/system/bin"
    TARGET_APP="/system/app"
    TARGET_INIT="/system/etc/init"
else
    TARGET_BIN="/bin"
    TARGET_APP="/app"
    TARGET_INIT="/etc/init"
#<<<<<<< fix-virtual-master-rom-magisk-injection-12963882449561167965
fi

guestfish -a "$ROM_IMG_PATH" -m /dev/sda <<EOF
mkdir-p ${TARGET_BIN}
upload $WORK_DIR/magisk ${TARGET_BIN}/magisk
chmod 0755 ${TARGET_BIN}/magisk
ln-sf ${TARGET_BIN}/magisk ${TARGET_BIN}/su
mkdir-p ${TARGET_APP}/Magisk
upload magisk.apk ${TARGET_APP}/Magisk/Magisk.apk
chmod 0644 ${TARGET_APP}/Magisk/Magisk.apk
mkdir-p ${TARGET_INIT}
upload $WORK_DIR/magisk.rc ${TARGET_INIT}/magisk.rc
chmod 0644 ${TARGET_INIT}/magisk.rc
EOF

echo "Patching rom.img sukses!"
#=======
fi

guestfish -a "$ROM_IMG_PATH" -m /dev/sda <<EOF
mkdir-p ${TARGET_BIN}
upload $WORK_DIR/magisk ${TARGET_BIN}/magisk
chmod 0755 ${TARGET_BIN}/magisk
ln-sf ${TARGET_BIN}/magisk ${TARGET_BIN}/su
mkdir-p ${TARGET_APP}/Magisk
upload magisk.apk ${TARGET_APP}/Magisk/Magisk.apk
chmod 0644 ${TARGET_APP}/Magisk/Magisk.apk
mkdir-p ${TARGET_INIT}
upload $WORK_DIR/magisk.rc ${TARGET_INIT}/magisk.rc
chmod 0644 ${TARGET_INIT}/magisk.rc
EOF

echo "Patching rom.img sukses!"

echo "=== 5.5. Kembalikan ke Format Asli ==="
# Kembalikan ke sparse image jika sebelumnya dikonversi
if [ "$IS_SPARSE" = true ]; then
    echo "Mengembalikan Raw Image menjadi Android Sparse Image..."
    img2simg "$ROM_IMG_PATH" "${ROM_IMG_PATH}.sparse"
    
    # Ganti file raw dengan yang sparse
    rm "$ROM_IMG_PATH"
    mv "${ROM_IMG_PATH}.sparse" "$ROM_IMG_PATH"
fi
#>>>>>>> main

echo "=== 6. Smart Repack ==="

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
