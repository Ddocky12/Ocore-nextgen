# Dokumentasi Pengembang & Audit Arsitektur — Ocore v3.0.0-NextGen

## 1. Ringkasan Hasil Audit Source Code & Binary (Ocore 2.2 &rarr; v3.0.0-NextGen)

### A. Audit Binary & Skrip Lama
1. **`zygisk/arm64-v8a.so` (`RaiRinModule`)**:
   - **Temuan**: Binary ELF 64-bit hasil patch path dari `/data/adb/modules/RaiRin-AI` menjadi `/data/adb/modules/Ocore//////cortex/OCORE.json` dan `/data/adb/modules/Ocore/////cortex/OCORE_spoof`. Fungsi companion `mount_spoof` menjalankan `/system/bin/mount --bind ... /proc/cpuinfo` di namespace mount global, yang berisiko membocorkan `/proc/cpuinfo` ke proses lain.
   - **Tindakan**: Binary asli dipertahankan agar modul langsung siap pakai (sesuai Aturan #11 & Bagian 23), default `with_cpu` diubah menjadi `false` (off), template `OCORE_spoof` disinkronkan dengan `/proc/cpuinfo` asli perangkat, dan source code C++17 baru yang bersih serta terisolasi (`unshare(CLONE_NEWNS)`) disediakan secara lengkap di `zygisk/src/ocore_zygisk.cpp`.
2. **`render/*` (`skia`, `skia-rec`, `skiagl-soft`, `vulkan`, `vulkan-rec`, `vulkan-soft`, `hybrid`, `hybrid-rec`, `hybrid-soft`)**:
   - **Temuan**: Wrapper ELF yang mendekripsi payload skrip shell menggunakan XOR 1-byte (`0xf7`, `0xfd`, `0x72`, `0xac`, `0x54`, `0xf0`, `0x38`, `0xa6`, `0x6e`) ke `/data/local/tmp/sys_render_XXXXXX`. Di dalam payload terenkripsi masih terdapat path lama `/data/local/tmp/RaiRin-AI/render/*.txt` dan perintah `am force-stop` yang mematikan game pengguna 5 detik setelah dibuka.
   - **Tindakan**: Path di dalam payload XOR seluruh binary `render/*` telah dipatch ke `/data/local/tmp/ocore////` dengan mempertahankan ukuran byte dan struktur ELF, ditambah symlink kompatibilitas `/data/local/tmp/RaiRin-AI -> /data/local/tmp/ocore`, serta pembaruan `gate.sh` & `break.sh` agar menerapkan properti renderer tanpa membunuh proses game aktif.
3. **`cortex/thermal/*` (`extreme1`, `extreme2`, `lite1`, `lite2`, `enable`, `backup`)**:
   - **Temuan**: Binary warisan RaiRin yang menghentikan service termal OEM (`thermald`, `vendor.thermal-hal-2-0`, `mi_thermald`), mem-bind-mount suhu palsu `37000` ke `/sys/class/thermal/thermal_zone*/temp`, dan menulis `ignore_thermal_protect 1`.
   - **Tindakan**: Seluruh skrip dispatcher `cortex/thermal/*.sh` telah diarahkan ulang ke `system/bin/thermod` (Ocore Thermal Intelligence v6.0) yang aman bagi perangkat dan tidak pernah mematikan proteksi termal OEM.

## 2. Instruksi Kompilasi Native Zygisk Module (`zygisk/src/`)

Source C++17 tersedia di `zygisk/src/`:
- `zygisk/src/zygisk.hpp` — Header ABI Zygisk v4
- `zygisk/src/ocore_zygisk.cpp` — Implementasi modul Zygisk per-aplikasi dengan isolasi namespace `CLONE_NEWNS`
- `zygisk/src/CMakeLists.txt` — Konfigurasi build CMake
- `zygisk/src/Android.mk` & `Application.mk` — Konfigurasi build `ndk-build`
- `zygisk/src/build_zygisk.sh` — Skrip build otomatis satu perintah

### Cara Membangun `zygisk/arm64-v8a.so` dengan Android NDK r25+:
```bash
export ANDROID_NDK_HOME=/path/to/android-ndk-r26b
cd zygisk/src
./build_zygisk.sh
```
Atau menggunakan `ndk-build`:
```bash
$ANDROID_NDK_HOME/ndk-build NDK_PROJECT_PATH=. APP_BUILD_SCRIPT=./Android.mk NDK_APPLICATION_MK=./Application.mk
```
