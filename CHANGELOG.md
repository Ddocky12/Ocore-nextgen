# OCORE v3.2.0-NextGen — Changelog & Engineering Audit Log

## [v3.2.0-NextGen] — 2026-11-10 (versionCode: 3200)

### 1. Prioritas 1 — Rebuild Floating FPS Pill (Strict FPS-Only HUD)
- **FPS-Only HUD**: Menghapus seluruh elemen non-FPS dari Floating Pill (`OverlayService.kt`), termasuk nama game, CPU%, GPU%, suhu, RAM, baterai, profil performa, tombol kontrol/pengaturan, dan panel ekspansi. Floating Pill kini hanya menampilkan angka FPS aktual (`"60 FPS"` atau `"-- FPS"` saat sumber tidak tersedia) dengan indikator titik kecil opsional (`6dp`).
- **Desain Visual Modern**: Kapsul horizontal ultra-ringkas (`padding 10dp × 5dp`), `CornerRadius 999dp` (full capsule), tampilan dark glass translucent (`#CC0B0F17`), dan border tipis `1dp` (`#26FFFFFF`).
- **Interaksi & Layar Aman**: Mendukung drag-and-drop dengan *edge snapping*, penyimpanan posisi (`SharedPreferences`), *clamping* batas aman layar saat rotasi portrait/landscape atau perubahan resolusi (`onConfigurationChanged`), serta mode *touch passthrough* (`FLAG_NOT_TOUCHABLE` opsional).
- **Sistem Warna FPS Adaptif Refresh Rate**: Ambang batas warna menyesuaikan target FPS dan refresh rate layar aktual (`60 Hz`, `90 Hz`, `120 Hz`, `144 Hz`) dengan ambang persentase yang dapat dikonfigurasi (`FPS_GREEN_PCT=85`, `FPS_YELLOW_PCT=60`):
  - **Hijau (`#00E676`)**: `>= 85%` target FPS (stabil & tinggi).
  - **Kuning (`#FFEA00`)**: `60% – 84%` target FPS (mulai menurun).
  - **Merah (`#FF5252`)**: `< 60%` target FPS (rendah / drop signifikan).
  - **Abu-abu (`#94A3B8`)**: `-- FPS` (sumber FPS tidak tersedia atau kadaluarsa `> 5000ms`).
- **Hierarki Sumber FPS Valid & Anti-Fake FPS**:
  1. `FrameTimeline` / SurfaceFlinger layer latency (`dumpsys SurfaceFlinger --latency`) melalui `FrameTimelineAdapter.kt`.
  2. Cache telemetri `ocore-fps-daemon` (`/dev/ocore_runtime/frame_stats.cache`) dengan validasi usia sampel (`<= 5 detik`).
  3. `dumpsys gfxinfo <pkg> framestats` sebagai *fallback* tervalidasi.
  - Tidak pernah menggunakan refresh rate layar sebagai pengganti FPS game dan tidak pernah menampilkan angka FPS palsu.

### 2. Prioritas 2 — Game-Only Floating Overlay & GameList Terpadu
- **Mesin Status Deterministik (`GameSessionStateMachine.kt` & `engine/core/gaming_engine.sh`)**:
  - Aktivasi: `IDLE → GAME_DETECTED → GAME_VALIDATED → OVERLAY_ACTIVE`
  - Penghentian: `OVERLAY_ACTIVE → GAME_EXITED → OVERLAY_HIDDEN → IDLE`
- **Satu Sumber Konfigurasi GameList**: `cortex/thunderclash/gamelist.txt` disinkronkan secara atomik dengan `cortex/thunderclash/game-active.txt`, `/data/adb/ocore/state/active_game_pkg`, `/data/adb/ocore/state/game_session_state.env`, `ocoreApplist.json`, `system/bin/ocore-game-daemon`, dan `engine/core/gaming_engine.sh`.
- **Pembersihan Non-Game**: Menghapus `flar2.devcheck` dari `gamelist.txt` dan menambahkan daftar hitam aplikasi sistem, launcher, keyboard, WhatsApp, browser, dan utilitas pada `cortex/thunderclash/game_blacklist.txt`.
- **Penghentian Instan di Luar Game**: Saat pengguna berpindah ke launcher, WhatsApp, browser, aplikasi biasa, menutup game, game mengalami *crash*, atau layar mati (`ACTION_SCREEN_OFF`), Floating Pill langsung disembunyikan (`OVERLAY_HIDDEN -> IDLE`) dan cache FPS dibersihkan.

### 3. Prioritas 3 & 4 — Redesign & Refactoring Aplikasi Android (`id.ocore.gamecontrol`)
- **Arsitektur Modular Modern**: Memisahkan UI dan logika bisnis ke dalam 8 komponen Kotlin (`MainActivity.kt`, `OverlayService.kt`, `OcoreRepository.kt`, `RootBridge.kt`, `Telemetry.kt`, `FrameTimelineAdapter.kt`, `GameListManager.kt`, `GameSessionStateMachine.kt`).
- **5 Halaman Utama Material 3 Dark Gaming Control Center**:
  1. `Dashboard`: Status modul OCORE, status koneksi root (`ACTIVE`, `INACTIVE`, `UNSUPPORTED`, `ERROR`), sesi game, FPS aktual, status Floating HUD, informasi perangkat, dan *quick controls*.
  2. `Gaming`: Manajemen GameList (`gamelist.txt`), deteksi aplikasi terinstal, tambah/hapus game bebas duplikat, profil per-game, dan pengaturan Auto Floating Pill.
  3. `Performance`: Pemilihan profil (`Balanced`, `Performance`, `Gaming`, `Powersave`, `Custom`) dan pengaturan renderer.
  4. `Monitoring`: Telemetri lengkap CPU, GPU, RAM, suhu multi-domain, baterai, serta riwayat sesi FPS (`Min`, `Avg`, `Max`, `P95`, `Jank%`) tanpa membebani Floating Pill.
  5. `Settings`: Konfigurasi Floating HUD (interval polling, ambang warna FPS, *touch passthrough*, *reset position*), izin overlay, diagnostik mandiri, dan informasi versi.

### 4. Prioritas 5, 6, 7, 8, 9 — Optimasi Modul, Keamanan Termal, 7 Subsistem Baru & WebUI
- **Perbaikan Bug Kritis**:
  - Memperbaiki korupsi sintaks `cortex/ocore_json_tool.sh` baris 179 (`2>killall ... || true1`).
  - Memperbaiki `cortex/thunderclash/perf1.sh` dan `psave1.sh` agar menerapkan fungsi `apply_policy_perf` dan `apply_policy_eco` ke seluruh `policy*` CPU.
  - Memperbaiki pemulihan proses di `cortex/thunderclash/ocore.sh` dengan snapshot per-PID (`/dev/ocore_runtime/pid_snapshots/session_pids.snap`) dan validasi identitas proses (`comm` + `starttime` dari `/proc/<pid>/stat`) untuk `nice`, `oom_score_adj`, `ionice`, `cpuset`, dan `schedtune/uclamp`.
  - Mengubah `system/bin/ocore-fps-daemon` menjadi sepenuhnya *on-demand* (berhenti melakukan *sampling* ketika tidak ada game valid yang aktif).
- **7 Subsistem Baru di `engine/core/`**:
  1. `adaptive_gaming_engine.sh`: Pemilihan sub-profil gaming adaptif berbasis beban kerja dan ruang kepala termal.
  2. `intelligent_fps_controller.sh`: Kalkulasi ambang warna FPS adaptif refresh rate (`60/90/120/144 Hz`) dan validasi kesegaran data.
  3. `smart_resource_manager.sh`: Pembatasan *cpuset* latar belakang secara aman saat bermain game dan pemulihan penuh saat keluar.
  4. `adaptive_polling_engine.sh`: Interval polling adaptif (`2s` saat game aktif, `4s` saat idle, `6s` saat layar mati, `0` FPS sampling saat idle).
  5. `gaming_engine.sh`: Mesin status sesi game dan sinkronisasi atomik GameList.
  6. `fps_history_engine.sh`: Pencatatan *ring-buffer* riwayat FPS dan kalkulasi metrik sesi (`Min`, `Avg`, `Max`, `P95`, `Jank%`).
  7. `config_integrity_manager.sh`: Validasi sintaks, pencadangan otomatis, dan pemulihan mandiri untuk `config.conf`, `gamelist.txt`, dan `OCORE.json`.
