# OCORE v3.2.0-NextGen — Laporan Pengujian (Test Report)

Setiap item pengujian diklasifikasikan secara ketat ke dalam empat kategori:
- **PASS**: Berhasil diverifikasi secara langsung melalui eksekusi skrip, parser, kompiler, atau simulasi sandbox.
- **FAIL**: Gagal dalam pengujian (0 item gagal setelah perbaikan).
- **NOT TESTED**: Tidak diuji karena berada di luar cakupan pengujian unit/statis.
- **NOT RUNTIME VERIFIED**: Logika dan kode telah diimplementasikan serta diverifikasi secara statis/fungsional, namun memerlukan perangkat Android fisik ber-root (KernelSU/Magisk/APatch) dan Android SDK untuk verifikasi runtime layar/kernel nyata.

---

## 1. Static Testing

| ID | Komponen / Target | Metode Verifikasi | Status | Detail Hasil |
| :--- | :--- | :--- | :--- | :--- |
| ST-01 | 71 Shell Scripts (`.sh` & `system/bin/*`) | `dash -n` (POSIX `/system/bin/sh`) & `bash -n` | **PASS** | 71/71 skrip lulus uji sintaks POSIX & Bash dengan 0 error |
| ST-02 | `cortex/ocore_json_tool.sh` (Perbaikan baris 179) | `dash -n` & eksekusi fungsi `list` / `audit` | **PASS** | Bug `2>killall ... || true1` berhasil diperbaiki |
| ST-03 | `cortex/thunderclash/perf1.sh` & `psave1.sh` | `dash -n` & inspeksi loop policy CPU | **PASS** | Loop `for pol in /sys/devices/system/cpu/cpufreq/policy*` ditambahkan |
| ST-04 | `OCORE.json` & `ocoreApplist.json` | `python3 -m json.tool` | **PASS** | Struktur JSON valid; `flar2.devcheck` dihapus dari daftar game |
| ST-05 | `webroot/index.html` JavaScript | `node --check` pada skrip inline | **PASS** | 0 syntax error; mendukung diffing DOM granular & preview FPS Pill |
| ST-06 | `zygisk/src/ocore_zygisk.cpp` | `g++ -std=c++17 -fsyntax-only` | **PASS** | 0 error kompilasi C++17 pada modul Zygisk |
| ST-07 | `AndroidManifest.xml` & 8 File Kotlin (`app/src/main/java/...`) | Validasi XML `ElementTree` & audit kecocokan kurung/impor/kontrak API | **PASS** | Seluruh 8 file sumber Kotlin + 1 file unit test memiliki struktur sintaks dan kontrak API yang konsisten |

---

## 2. Functional Testing (Sandbox Execution)

| ID | Skenario Pengujian | Metode Eksekusi | Status | Detail Hasil |
| :--- | :--- | :--- | :--- | :--- |
| FT-01 | Migrasi & Integritas Konfigurasi (`config_migrate`, `config_integrity`) | Eksekusi `sh ocorectl config_migrate` & `config_integrity` | **PASS** | Menghasilkan skema `CONFIG_VERSION=3200` dan mencadangkan konfigurasi secara atomik |
| FT-02 | GameList: Penambahan Game Valid (`com.teststudio.supergame`) | `sh ocorectl gamelist_add com.teststudio.supergame` | **PASS** | Paket ditambahkan ke `gamelist.txt` dan disinkronkan ke `ocoreApplist.json` |
| FT-03 | GameList: Pencegahan Duplikat | Menambahkan paket yang sama dua kali | **PASS** | Duplikat ditolak dengan aman tanpa menggandakan baris di `gamelist.txt` |
| FT-04 | GameList: Penolakan Aplikasi Blacklist (`com.whatsapp`) | `sh ocorectl gamelist_add com.whatsapp` | **PASS** | Ditolak dengan `TRANSACTION_STATUS=FAILED` karena termasuk aplikasi komunikasi non-game |
| FT-05 | GameList: Validasi Format Nama Paket (`invalid_pkg_no_dot`) | `sh ocorectl gamelist_add invalid_pkg_no_dot` | **PASS** | Ditolak oleh validator regex nama paket Android |
| FT-06 | Sesi Game: Transisi Masuk Game (`game_enter com.miHoYo.GenshinImpact`) | `sh ocorectl game_enter com.miHoYo.GenshinImpact` | **PASS** | `SESSION_STATE=OVERLAY_ACTIVE`, `OVERLAY_ALLOWED=1`, `game-active.txt` berisi `com.miHoYo.GenshinImpact` |
| FT-07 | Kalkulasi Ambang Warna FPS Adaptif (`60/90/120/144 Hz`) | `intelligent_fps_controller.sh` | **PASS** | Pada `58 FPS`: `60Hz -> GREEN`, `90Hz -> YELLOW`, `120Hz -> RED`, `144Hz -> RED` |
| FT-08 | Sesi Game: Transisi Keluar Game (`game_exit`) & Pembersihan | `sh ocorectl game_exit` | **PASS** | `SESSION_STATE=IDLE`, `OVERLAY_ALLOWED=0`, `game-active.txt` dikosongkan, `frame_stats.cache` dihapus |
| FT-09 | Pembersihan Otomatis Saat Game Crash / Berhenti Mendadak | Menghapus proses game saat `OVERLAY_ACTIVE` lalu memanggil `frame_stats` | **PASS** | Mendeteksi proses berhenti, mengembalikan `-- FPS` (`GRAY`), dan mereset status ke `IDLE` |
| FT-10 | Validasi Identitas PID Saat Restore (`ocore.sh`) | Pemeriksaan format snapshot `PID|COMM|STARTTIME|NICE|OOM|...` | **PASS** | `restore_game_processes` memverifikasi `starttime` `/proc/<pid>/stat` sebelum memulihkan nilai |

---

## 3. Performance & Compatibility Testing

| ID | Parameter Evaluasi | Hasil Pengukuran / Verifikasi | Status |
| :--- | :--- | :--- | :--- |
| PT-01 | Latensi Eksekusi `ocorectl status` + `ocorectl frame_stats` | Rata-rata **19 ms** per pasang pemanggilan (98 ms untuk 5 iterasi beruntun) | **PASS** |
| PT-02 | Overhead Daemon FPS Saat Tidak Ada Game (`IDLE`) | **0% CPU sampling** — `ocore-fps-daemon` keluar otomatis saat `IDLE` dan hanya dijalankan oleh `ocore-game-daemon` saat game valid aktif | **PASS** |
| PT-03 | Kompatibilitas POSIX `/system/bin/sh` & Toybox | Tidak menggunakan array Bash (`declare -a`), `[[ ... ]]`, atau fitur spesifik GNU coreutils | **PASS** |
| PT-04 | Kompatibilitas Refresh Rate Layar (`60/90/120/144 Hz`) | Diuji pada ke-4 profil refresh rate dengan kalkulasi ambang persentase dinamis | **PASS** |
| RT-01 | Kompilasi Binary APK (`assembleDebug`) & Uji Layar Perangkat Nyata | Lingkungan VM tidak memiliki Android SDK (`android.jar`, `kotlinc`, `d8`, `aapt2`) maupun perangkat Android fisik; proyek Gradle Kotlin disediakan lengkap untuk dikompilasi di Android Studio / CI | **NOT RUNTIME VERIFIED** |
| RT-02 | Penulisan Langsung ke Node Kernel `/proc/gpufreqv2`, `/proc/eem`, `/sys/kernel/fpsgo` | Diverifikasi melalui *dry-run* dan simulasi sandbox; eksekusi pada node hardware SoC membutuhkan kernel perangkat Android fisik | **NOT RUNTIME VERIFIED** |
