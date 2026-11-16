# OCORE v3.2.0-NextGen — Dokumentasi Fitur & Arsitektur

## 1. Floating FPS-Only HUD (`OverlayService.kt` & `intelligent_fps_controller.sh`)
- **Tampilan Eksklusif FPS**: Hanya menampilkan `"60 FPS"` (atau `"-- FPS"` bila telemetri belum tersedia) beserta indikator titik kecil status pengukuran.
- **Warna Adaptif Refresh Rate (`60Hz / 90Hz / 120Hz / 144Hz`)**:
  - **Hijau (`GREEN`)**: FPS `>= FPS_GREEN_PCT%` (default `85%`) dari target FPS layar/game.
  - **Kuning (`YELLOW`)**: FPS antara `FPS_YELLOW_PCT%` (default `60%`) hingga `< 85%` dari target FPS.
  - **Merah (`RED`)**: FPS `< 60%` dari target FPS.
  - **Abu-abu (`GRAY`)**: Sumber FPS tidak tersedia atau sampel berusia `> 5 detik`.
- **Sumber Pengukuran Berlapis**:
  1. `FrameTimeline` / `dumpsys SurfaceFlinger --latency <layer>` (prioritas utama).
  2. Cache `/dev/ocore_runtime/frame_stats.cache` dari `ocore-fps-daemon`.
  3. `dumpsys gfxinfo <package> framestats` (fallback).

## 2. Game-Only Overlay & Mesin Status Sesi Game (`gaming_engine.sh` & `GameSessionStateMachine.kt`)
- **Alur Transisi Status**:
  - Saat masuk game: `IDLE → GAME_DETECTED → GAME_VALIDATED → OVERLAY_ACTIVE`
  - Saat keluar game: `OVERLAY_ACTIVE → GAME_EXITED → OVERLAY_HIDDEN → IDLE`
- **Validasi Berlapis**:
  1. Aplikasi *foreground* terdeteksi (`ocore-game-daemon` / `Telemetry.kt`).
  2. Nama paket terdaftar di `cortex/thunderclash/gamelist.txt`.
  3. Nama paket tidak berada di `cortex/thunderclash/game_blacklist.txt` atau daftar sistem/utilitas.
  4. Proses game hidup (`/proc/<pid>`) dan layar menyala.

## 3. Tujuh Subsistem Inti Baru (`engine/core/`)
1. **Adaptive Gaming Engine (`adaptive_gaming_engine.sh`)**: Menentukan sub-profil (`GAMING_ULTRA`, `GAMING_SUSTAINED`, `BALANCED_COOL`, `THERMAL_EMERGENCY`) berdasarkan beban frame dan suhu perangkat.
2. **Intelligent FPS Controller (`intelligent_fps_controller.sh`)**: Mengelola ambang warna FPS dinamis sesuai refresh rate layar (`60/90/120/144 Hz`).
3. **Smart Resource Manager (`smart_resource_manager.sh`)**: Mengarahkan *cpuset* aplikasi latar belakang ke kluster efisiensi selama sesi game tanpa mematikan layanan komunikasi penting, lalu memulihkan nilai asli saat game ditutup.
4. **Adaptive Polling Engine (`adaptive_polling_engine.sh`)**: Menyesuaikan frekuensi pemindaian daemon berdasarkan status layar dan sesi game.
5. **Game Session Manager (`gaming_engine.sh`)**: Mengelola siklus hidup sesi game dan sinkronisasi atomik `gamelist.txt`.
6. **FPS History Engine (`fps_history_engine.sh`)**: Menyimpan *ring-buffer* 200 sampel terakhir dan menghitung `MIN_FPS`, `AVG_FPS`, `MAX_FPS`, `AVG_P95_MS`, dan `AVG_JANK_PCT`.
7. **Configuration Integrity Manager (`config_integrity_manager.sh`)**: Memvalidasi integritas file konfigurasi dan memulihkan cadangan terakhir yang valid jika ditemukan kerusakan.

## 4. Pemulihan Proses Per-PID yang Aman (`cortex/thunderclash/ocore.sh`)
- Menyimpan snapshot nilai awal (`nice`, `oom_score_adj`, `ionice class/prio`, `cpuset`, `stune`) beserta `comm` dan `starttime` (`/proc/<pid>/stat` field ke-22) di `/dev/ocore_runtime/pid_snapshots/session_pids.snap`.
- Saat sesi game berakhir, hanya memulihkan proses apabila PID masih hidup **dan** memiliki `comm` serta `starttime` yang identik, sehingga mencegah pemulihan salah sasaran pada PID yang telah digunakan ulang oleh proses baru.
