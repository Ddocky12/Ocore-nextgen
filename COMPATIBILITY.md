# Matriks Kompatibilitas — Ocore v3.0.0-NextGen

## 1. Dukungan Keluarga SoC

| Keluarga SoC | Status Dukungan | Fitur Spesifik yang Aktif | Fallback untuk Node Tidak Tersedia |
| :--- | :--- | :--- | :--- |
| **MediaTek Dimensity / Helio** | `SUPPORTED` (Tuned penuh untuk MT6877 / Dimensity) | CPU DVFS, GPUFreq v1/v2, GED Boost, FPSGO Ceiling, PPM, `/proc/mtktz`, EEM Voltage (jika diekspos kernel) | Otomatis menonaktifkan kontrol EEM/GED jika node tidak ada |
| **Qualcomm Snapdragon** | `SUPPORTED` (Generic + Adreno KGSL) | CPU DVFS, Adreno KGSL Devfreq (`/sys/class/kgsl/kgsl-3d0/devfreq`), Cpuset/EAS, ZRAM/VM, Block I/O, Gaming & Spoof | Kontrol khusus MediaTek (`EEM`, `FPSGO`, `GED`, `.tp`) otomatis ditandai `UNSUPPORTED` |
| **Samsung Exynos** | `SUPPORTED` (Generic + Mali Devfreq) | CPU DVFS, Mali Devfreq, Cpuset/EAS, ZRAM/VM, Block I/O, Thermal Zones `/sys/class/thermal`, Gaming & Spoof | Node spesifik MTK/QCOM dilewati dengan aman |
| **UNISOC** | `SUPPORTED` (Generic + Devfreq) | CPU DVFS, Generic Devfreq, Cpuset/EAS, ZRAM/VM, Thermal Monitoring, Gaming & Spoof | Node spesifik vendor lain dinonaktifkan |
| **Google Tensor** | `SUPPORTED` (Generic + Mali Devfreq) | CPU DVFS, Mali Devfreq, Cpuset/EAS, ZRAM/VM, Thermal Monitoring, Gaming & Spoof | Node spesifik vendor lain dinonaktifkan |
| **SoC Lain / Tidak Dikenali** | `SAFE GENERIC MODE` (`SOC_ID=0`) | Hanya mengaktifkan fitur standar Linux/Android (`cpufreq`, `/proc/sys/vm`, `/sys/class/thermal`, Gaming & Spoof) | Tidak menerapkan konfigurasi hardware vendor lain |

## 2. Dukungan Root Manager & WebUI Bridge

| Root Manager | Status Bridge | Mekanisme Eksekusi |
| :--- | :--- | :--- |
| **KernelSU** | `SUPPORTED` | `ksu.exec(cmd, opts, cb)` via `KernelSUAdapter` |
| **KernelSU Next** | `SUPPORTED` | `ksu.exec` / `ksu.spawn` via `KernelSUNextAdapter` |
| **APatch** | `SUPPORTED` | `apatch.exec(cmd, cb)` via `APatchAdapter` |
| **Magisk + WebUI-X / MMRL** | `SUPPORTED` | `window.webui.exec` / `$ocore_mmrl` via `MagiskWebUIXAdapter` |
| **Browser Standar (Tanpa Root)** | `READ-ONLY FALLBACK` | `DisconnectedReadOnlyAdapter` (Menampilkan banner offline & `UNAVAILABLE` tanpa data palsu) |

## 3. Catatan Verifikasi Runtime (Section 21.D)
- Pengujian statik, fungsional skrip, transaksi konfigurasi, simulasi node sysfs/procfs, manajemen JSON, dan kompilasi sintaks C++17 telah **diverifikasi penuh** di lingkungan build Linux.
- Fitur yang bergantung langsung pada register hardware spesifik perangkat fisik (seperti penulisan register `/proc/eem/*/eem_offset` pada silikon MT6877, transaksi Binder `SurfaceFlinger 1035`, dan injeksi Zygote runtime oleh `zygisk/arm64-v8a.so`) secara jujur ditandai sebagai **`NOT_RUNTIME_VERIFIED`** ketika dijalankan di luar kernel perangkat Android target.
