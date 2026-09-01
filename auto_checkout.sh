#!/system/bin/sh
# auto_checkout.sh
#
# Setiap hari jam 23:59, script ini menunggu scanner benar-benar idle
# (tidak ada transaksi berjalan), lalu otomatis menekan tombol Bayar,
# memilih metode Cash, dan mengonfirmasi transaksi -- supaya barang
# yang sudah discan tapi lupa dibayar tidak menggantung sampai besok.
#
# Koordinat di bawah adalah hasil trial & error di layar 1920x1080.
# Cara cari koordinat versi kamu sendiri: lihat docs/setup-guide.md.

CHARGE_X=1500
CHARGE_Y=950
CASH_X=1800
CASH_Y=490
CONFIRM_X=960
CONFIRM_Y=950
SCANNER_DEV=/dev/input/event7

while true; do
  # --- Tunggu sampai jam 23:59, dihitung manual (aman untuk Toybox/Android) ---
  while true; do
    H=$(date +%H)
    M=$(date +%M)
    S=$(date +%S)
    CURRENT_SECONDS=$(( (10#$H * 3600) + (10#$M * 60) + (10#$S) ))
    TARGET_SECONDS=$(( (23 * 3600) + (59 * 60) ))
    if [ "$CURRENT_SECONDS" -ge "$TARGET_SECONDS" ]; then
      break
    fi
    sleep 5
  done

  # --- Tunggu scanner benar-benar idle (3 detik tanpa input) ---
  # Ini mencegah checkout otomatis nyelonong di tengah transaksi
  # yang masih berjalan.
  idle_check=0
  while [ "$idle_check" -lt 3 ]; do
    if timeout 1 getevent -c 1 "$SCANNER_DEV" >/dev/null 2>&1; then
      idle_check=0
      sleep 1
    else
      idle_check=$((idle_check + 1))
    fi
  done

  # --- Eksekusi checkout ---
  su -c "input tap $CHARGE_X $CHARGE_Y"
  sleep 1
  su -c "input tap $CASH_X $CASH_Y"
  sleep 1
  su -c "input tap $CONFIRM_X $CONFIRM_Y"
  sleep 1

  # Kembalikan fokus ke kolom search biar siap dipakai lagi besok pagi
  su -c "input tap 1208 56"

  # Tidur 65 detik supaya tidak double-trigger di menit yang sama
  sleep 65
done
