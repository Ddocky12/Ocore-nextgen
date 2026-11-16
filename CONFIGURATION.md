# OCORE v3.2.0-NextGen — Panduan Konfigurasi & Antarmuka CLI (`ocorectl`)

## 1. File Konfigurasi Utama (`/data/adb/ocore/config.conf`)

| Kunci Konfigurasi | Nilai Default | Rentang / Opsi Valid | Deskripsi |
| :--- | :--- | :--- | :--- |
| `CONFIG_VERSION` | `3200` | `3200` | Versi skema konfigurasi OCORE v3.2.0-NextGen |
| `GLOBAL_PROFILE` | `balanced` | `powersave`, `balanced`, `performance`, `gaming`, `custom` | Profil performa sistem global |
| `AUTO_FLOATING_HUD` | `1` | `0`, `1` | Mengaktifkan/menonaktifkan Floating FPS Pill otomatis saat game dalam GameList dibuka |
| `HUD_POLL_INTERVAL_MS` | `2000` | `500` – `10000` | Interval pengambilan sampel FPS pada Floating Pill (milidetik) |
| `FPS_GREEN_PCT` | `85` | `70` – `98` | Ambang persentase dari target FPS untuk indikator warna Hijau (`GREEN`) |
| `FPS_YELLOW_PCT` | `60` | `40` – `84` | Ambang persentase dari target FPS untuk indikator warna Kuning (`YELLOW`) |
| `SMART_RESOURCE_MGR` | `1` | `0`, `1` | Mengaktifkan pengoptimalan cpuset/VFS otomatis selama sesi game |
| `ADAPTIVE_GAMING_ENGINE` | `1` | `0`, `1` | Mengaktifkan penyesuaian sub-profil gaming adaptif berbasis termal & beban frame |
| `SMART_GUARD` | `1` | `0`, `1` | Proteksi termal berlapis tanpa mematikan thermal daemon OEM |

## 2. File Konfigurasi GameList & Sesi Game

| Lokasi File | Peran & Sinkronisasi |
| :--- | :--- |
| `cortex/thunderclash/gamelist.txt` | **Sumber utama (Canonical Source)** daftar paket game OCORE (1 paket per baris) |
| `cortex/thunderclash/game_blacklist.txt` | Daftar paket non-game (launcher, sistem, WhatsApp, browser, utilitas) yang dilarang memicu overlay |
| `cortex/thunderclash/game-active.txt` | Menyimpan nama paket game yang sedang aktif divalidasi (kosong saat `IDLE`) |
| `/data/adb/ocore/state/active_game_pkg` | Menyimpan nama paket game aktif (`None` saat `IDLE`) untuk sinkronisasi daemon & aplikasi |
| `/data/adb/ocore/state/game_session_state.env` | Menyimpan status mesin sesi (`SESSION_STATE`, `ACTIVE_GAME_PKG`, `OVERLAY_ALLOWED`, `AUTO_FLOATING_HUD`) |
| `ocoreApplist.json` | Mirror JSON yang dihasilkan otomatis dari `cortex/thunderclash/gamelist.txt` |

## 3. Subcommand `ocorectl` (Allowlisted di `RootBridge.kt`)

- `ocorectl status` — Menampilkan telemetri lengkap perangkat, CPU/GPU/RAM/Suhu, profil, dan status sesi game.
- `ocorectl frame_stats [pkg]` — Menampilkan metrik FPS aktual, warna indikator (`GREEN/YELLOW/RED/GRAY`), sumber FPS, dan status sesi.
- `ocorectl game_session_state` — Menampilkan status mesin sesi game (`IDLE`, `GAME_DETECTED`, `GAME_VALIDATED`, `OVERLAY_ACTIVE`, `GAME_EXITED`, `OVERLAY_HIDDEN`).
- `ocorectl gamelist_get` — Membaca daftar paket game tervalidasi dari `cortex/thunderclash/gamelist.txt`.
- `ocorectl gamelist_add <package>` — Menambahkan game baru (dengan validasi regex, anti-duplikat, dan pemeriksaan blacklist).
- `ocorectl gamelist_remove <package>` — Menghapus game dari `gamelist.txt` dan menyinkronkan mirror JSON.
- `ocorectl gamelist_sync` — Menyinkronkan `gamelist.txt` dengan `ocoreApplist.json`.
- `ocorectl auto_hud <0|1>` — Mengatur opsi global Auto Floating FPS Pill.
- `ocorectl hud_poll <500..10000>` — Mengatur interval polling Floating FPS Pill dalam milidetik.
- `ocorectl fps_thresholds <green_pct> <yellow_pct>` — Mengatur ambang warna FPS adaptif.
- `ocorectl fps_history` — Menampilkan ringkasan sesi FPS (`MIN_FPS`, `AVG_FPS`, `MAX_FPS`, `AVG_P95_MS`, `AVG_JANK_PCT`) dan sampel terbaru.
- `ocorectl adaptive_workload [pkg]` — Mengevaluasi beban kerja dan ruang kepala termal game aktif.
- `ocorectl config_integrity` — Memvalidasi dan memulihkan integritas file konfigurasi.
