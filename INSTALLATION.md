# Panduan Instalasi & Uninstalasi — Ocore v3.0.0-NextGen

## 1. Persyaratan Sistem
- Android 11 hingga Android 16 (API 30 – 36), arsitektur **ARM64 (`arm64-v8a`)** atau **ARMv7 (`armeabi-v7a`)**.
- Root Manager: **KernelSU**, **KernelSU Next**, **APatch**, atau **Magisk v24.0+** (dengan Zygisk aktif jika ingin menggunakan fitur simulasi profil perangkat per aplikasi).
- Disarankan menonaktifkan modul performa/termal lain (seperti *RaiRin-AI*, *AZenith*, *ThermodMT6877*, *laya_kerneltuner*, *mtkvoltoptimizer*) untuk menghindari konflik penulisan node sysfs.

## 2. Langkah Instalasi
1. Buka aplikasi Root Manager (**KernelSU / KernelSU Next / APatch / Magisk**).
2. Pilih menu **Modules** &rarr; **Install from storage** dan pilih file `Ocore_v3.0.0-NextGen_Unified.zip`.
3. Skrip `customize.sh` akan:
   - Memvalidasi arsitektur, versi Android, dan keluarga SoC (menggunakan **Safe Generic Mode** jika SoC belum dikenali).
   - Memeriksa modul lain yang berpotensi bentrok secara **non-destruktif** (tanpa menghapus modul pengguna).
   - Mencadangkan konfigurasi termal bawaan `/vendor/etc/.tp` (jika ada) ke `/data/adb/thermod_mt6877/backup/`.
   - Menginisialisasi dan memigrasikan `/data/adb/ocore/config.conf` ke skema `v3.0.0` (`CONFIG_VERSION=3000`).
   - Membuat template `/proc/cpuinfo` (`cortex/OCORE_spoof`) sesuai jumlah core aktual perangkat.
4. Reboot perangkat Anda.

## 3. Langkah Uninstalasi Bersih (`uninstall.sh`)
Saat modul dihapus melalui Root Manager dan perangkat di-reboot, `uninstall.sh` akan:
1. Menghentikan seluruh daemon milik Ocore setelah memverifikasi identitas proses (`/proc/<pid>/cmdline`).
2. Memulihkan offset voltase `/proc/eem*` ke baseline asli yang dicapture di `/data/adb/ocore/backups/eem_initial_stock.env`.
3. Memulihkan seluruh node kernel ke nilai awal boot (`kernel_nodes_initial.env`) dan membuka kunci batas frekuensi CPU/GPU.
4. Memulihkan konfigurasi termal bawaan dari cadangan terverifikasi.
5. Mengaktifkan kembali pengisian daya baterai normal di seluruh node charger.
6. Melepas bind-mount `/proc/cpuinfo` (jika ada), menghapus properti `persist.sys.ocore*`, dan membersihkan direktori `/data/adb/ocore` tanpa menyentuh modul lain atau data pengguna.
