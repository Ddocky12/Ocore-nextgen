# Panduan Sistem Pemulihan (Recovery & Rollback) — Ocore v3.0.0-NextGen

Ocore v3.0.0-NextGen dilengkapi perlindungan berlapis terhadap ketidakstabilan perangkat, kegagalan konfigurasi, maupun bootloop.

## 1. Anti-Bootloop Otomatis 2-Tahap (`post-fs-data.sh`)
- **Tahap 1 (`BOOTCOUNT = 2`)**: Jika perangkat gagal mencapai `sys.boot_completed=1` pada boot sebelumnya, Ocore otomatis mengembalikan profil voltase EEM ke `STOCK` (`0/0/0/0`) dan mengunci `GLOBAL_PROFILE=balanced`.
- **Tahap 2 (`BOOTCOUNT >= 3`)**: Jika 3 kali boot berturut-turut gagal selesai, Ocore otomatis membuat file `disable` pada direktori modul, menyimpan log kernel terakhir ke `/data/adb/ocore/logs/last_bootloop_failure.log`, dan menonaktifkan dirinya sendiri agar perangkat dapat menyala normal.

## 2. Pemulihan Melalui Tombol Action Root Manager (`action.sh`)
Anda dapat menjalankan perintah pemulihan melalui terminal (`adb shell su -c ...` atau Termux):
- **Emergency Safe Mode**:
  ```sh
  su -c sh /data/adb/modules/Ocore/action.sh --safe-mode
  ```
- **Restore All Stock (EEM, Thermal, CPU/GPU, Charging, Renderer, Config)**:
  ```sh
  su -c sh /data/adb/modules/Ocore/action.sh --restore-all
  ```

## 3. Pemulihan Granular Melalui CLI (`ocorectl`)
- `su -c ocorectl recovery emergency_safe_mode` — Mengaktifkan Safe Mode (Priority #2), mereset EEM & Thermal ke Stock, dan mengunci profil ke Balanced.
- `su -c ocorectl recovery restore_all_stock` — Memulihkan seluruh subsistem ke kondisi bawaan pabrik.
- `su -c ocorectl recovery eem_restore` — Memulihkan rail `/proc/eem*` ke baseline awal perangkat.
- `su -c ocorectl recovery thermal_restore` — Memulihkan konfigurasi termal OEM bawaan.
- `su -c ocorectl recovery kernel_node_restore` — Memulihkan seluruh sysfs/procfs yang pernah diubah ke nilai awal boot (`kernel_nodes_initial.env`).
- `su -c ocorectl recovery charging_restore` / `su -c ocorectl emergency_charge_recover` — Memaksa pengisian daya kembali normal jika Bypass/Smart Charging macet.
- `su -c ocorectl recovery spoof_restore` — Menghapus seluruh binding profil perangkat di `OCORE.json`.
- `su -c ocorectl recovery daemon_recovery` — Mereset penghitung crash/cooldown dan memulai ulang daemon yang aktif.
