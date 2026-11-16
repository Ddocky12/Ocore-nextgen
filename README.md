# Ocore Unified Performance Engine — v3.0.0-NextGen

**Ocore v3.0.0-NextGen** adalah modul performa Android tingkat sistem yang dirancang untuk **KernelSU, KernelSU Next, APatch, dan Magisk (Zygisk)**. Versi generasi baru ini merupakan hasil audit menyeluruh, refactoring modular, perbaikan bug akar masalah, dan perombakan WebUI dari **Ocore 2.2**.

## Arsitektur Modular (v3.0.0-NextGen)

Seluruh subsistem diorganisasikan secara modular di bawah `engine/core/` dan dikoordinasikan oleh `system/bin/ocorectl`:

| Subsistem | File Modul | Fungsi Utama |
| :--- | :--- | :--- |
| **Core Engine** | `engine/core/core_engine.sh` | Atomic config/state writer, directory locking (`mkdir` + stale PID check), structured logging & error registry |
| **Hardware Detection Engine** | `engine/core/hw_detect.sh` | Deteksi SoC (MediaTek, Snapdragon, Exynos, UNISOC, Tensor, Safe Generic Mode) & matriks kapabilitas 3-status (`SUPPORTED`, `UNSUPPORTED`, `UNKNOWN`) |
| **Priority Arbiter** | `engine/core/arbiter.sh` | Hirarki prioritas 6-tingkat dengan verifikasi readback dan rollback otomatis |
| **CPU Controller** | `engine/core/cpu_engine.sh` | Kontrol frekuensi & governor per-policy dinamis, profil Custom, tuning Schedutil, partisi EAS/Cpuset |
| **GPU Controller** | `engine/core/gpu_engine.sh` | Kontrol DVFS GPU lintas vendor (MTK GPUFreq v1/v2, Adreno KGSL, Mali Devfreq) dengan proteksi termal aktif |
| **Thermal Intelligence** | `engine/core/thermal_engine.sh` & `system/bin/thermod` | State machine multi-domain (`NORMAL`, `WARM`, `HOT`, `CRITICAL`), histeresis, cooldown, dan 4 mode aman tanpa mematikan proteksi OEM |
| **Voltage Stability Engine** | `engine/core/voltage_engine.sh` | Capture baseline awal `/proc/eem*`, offset konservatif/custom tervalidasi (`[-12..+4]`), verifikasi readback & anti-bootloop 2-tahap |
| **Gaming Engine** | `engine/core/gaming_engine.sh` & `system/bin/ocore-game-daemon` | Deteksi sesi game akurat (memfilter launcher/keyboard/SystemUI/overlay), konfigurasi per-game, pemulihan penuh saat keluar/crash/layar mati |
| **Device Profile Engine** | `engine/core/device_profile_engine.sh` & `cortex/ocore_json_tool.sh` | Database 20 profil perangkat terverifikasi di `cortex/OCORE.json`, pengelola JSON atomik bebas `awk` rapuh, dan source C++17 Zygisk (`zygisk/src/`) |
| **Renderer Engine** | `engine/core/renderer_engine.sh`, `gate.sh`, `break.sh` | Pipeline `default`, `skiagl`, `skiavk`, `hybrid` dengan pemeriksaan driver Vulkan dan sinkronisasi status penuh |
| **Battery Intelligence** | `engine/core/battery_engine.sh` & `engine/ocore-bypass` | Telemetri baterai lengkap, Smart Charging, Direct Bypass Charging terverifikasi hardware, dan Emergency Charging Recovery |
| **Memory & Storage Engine** | `engine/core/memory_storage_engine.sh` | Telemetri terpisah RAM Total/Used/Available/Cache & ZRAM, tuning VM, I/O scheduler, FSTrim, dan One-Tap Optimization aman |
| **Daemon Manager** | `engine/core/daemon_manager.sh` | Manajemen PID dengan verifikasi identitas `/proc/<pid>/cmdline`, pencegahan duplikasi, dan circuit-breaker cooldown |
| **Diagnostics & Recovery** | `engine/core/diagnostics_engine.sh` & `engine/core/recovery_manager.sh` | Audit 16-titik, ekspor bundel diagnostik, Emergency Safe Mode, dan pemulihan penuh ke kondisi Stock |

## Peta Dependensi (Dependency Map)

```
WebUI (webroot/index.html — 8 Halaman)
  └── RootBridge Adapter (KernelSUNext / KernelSU / APatch / MagiskWebUIX / DisconnectedReadOnly)
        └── Dynamic Path Resolver -> /data/adb/modules/Ocore/system/bin/ocorectl
              ├── engine/core/*.sh (16 Modular Subsystems)
              ├── system/bin/thermod (Multi-Domain Thermal Intelligence CLI v6.0)
              ├── cortex/ocore_json_tool.sh -> cortex/OCORE.json & cortex/OCORE_spoof
              ├── system/bin/ocore-game-daemon (Foreground Game & Screen State Daemon)
              ├── system/bin/ocore-fps-daemon (SurfaceFlinger Frame Pacing & Jank Monitor)
              ├── engine/ocore-bypass (Hardware-Verified Bypass Charging Keeper)
              ├── gate.sh & break.sh (Per-Game & Global Graphics Renderer Dispatcher)
              └── Kernel Interfaces (/sys/devices/system/cpu/cpufreq, /proc/eem*, /sys/class/thermal, /proc/gpufreq*, /sys/class/kgsl, /dev/cpuset, /proc/sys/vm)
```

## Dokumentasi Lengkap

- `CHANGELOG.md` — Daftar perubahan lengkap dari Ocore 2.2 ke v3.0.0-NextGen
- `FEATURES.md` — Rincian seluruh fitur dan cara kerjanya
- `COMPATIBILITY.md` — Matriks kompatibilitas SoC, Android, dan Root Manager
- `INSTALLATION.md` — Panduan instalasi, migrasi, dan uninstall
- `RECOVERY.md` — Panduan pemulihan darurat (WebUI, Action Button, dan CLI)
- `DEVELOPER.md` — Audit source code, arsitektur internal, dan instruksi kompilasi C++ Zygisk
- `TEST_REPORT.md` — Laporan hasil pengujian statik, fungsional, dan ketahanan gagal (failure testing)
