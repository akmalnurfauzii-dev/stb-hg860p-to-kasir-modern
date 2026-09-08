#!/system/bin/sh
# auto_checkout.sh
#
# Setiap hari jam 23:59, script ini menunggu scanner benar-benar idle
# (tidak ada transaksi berjalan), lalu otomatis menekan tombol Charge,
# memilih metode Cash, dan mengonfirmasi transaksi -- supaya barang
# yang sudah discan tapi lupa dibayar tidak menggantung sampai besok.
#
# Koordinat di bawah adalah hasil trial & error di layar 1920x1080.
# Cara cari koordinat versi kamu sendiri: lihat docs/setup-guide.md.
#
# PENTING -- kenapa versi ini pakai polling 30 detik, bukan sleep
# panjang sekali tembak: lihat "Kenapa polling, bukan sleep panjang"
# di docs/setup-guide.md. Ringkasnya, Android (Doze Mode) cenderung
# membunuh proses yang "menganggur" lewat sleep jangka panjang; dengan
# polling tiap 30 detik, proses selalu terlihat aktif oleh sistem.

LOG=/sdcard/checkout_log.txt
echo "=== Script started at $(date) ===" >> "$LOG"

CHARGE_X=1500
CHARGE_Y=950
CASH_X=1800
CASH_Y=490
CONFIRM_X=960
CONFIRM_Y=950
SCANNER_DEV=/dev/input/event7

while true; do
  H=$(date +%H)
  M=$(date +%M)
  S=$(date +%S)
  CURRENT_SECONDS=$(( (${H#0} * 3600) + (${M#0} * 60) + ${S#0} ))
  TARGET_SECONDS=$(( 23 * 3600 + 59 * 60 ))  # 23:59:00

  echo "$(date) - loop alive, current=$CURRENT_SECONDS target=$TARGET_SECONDS" >> "$LOG"

  # Jendela toleransi 90 detik (23:59:00 - 23:59:90) supaya tetap
  # ke-trigger walau granularitas polling 30 detik sedikit meleset.
  if [ "$CURRENT_SECONDS" -ge "$TARGET_SECONDS" ] && [ "$CURRENT_SECONDS" -lt $((TARGET_SECONDS + 90)) ]; then
    echo "$(date) - TRIGGER CHECKOUT" >> "$LOG"

    # Tunggu scanner benar-benar idle (3 detik tanpa input) supaya
    # tidak nyelonong di tengah transaksi yang masih berjalan.
    idle_check=0
    while [ "$idle_check" -lt 3 ]; do
      if timeout 1 getevent -c 1 "$SCANNER_DEV" >/dev/null 2>&1; then
        idle_check=0
        sleep 1
      else
        idle_check=$((idle_check + 1))
      fi
    done

    su -c "input tap $CHARGE_X $CHARGE_Y"
    sleep 1
    su -c "input tap $CASH_X $CASH_Y"
    sleep 1
    su -c "input tap $CONFIRM_X $CONFIRM_Y"
    sleep 1
    su -c "input tap 1208 56"  # balik fokus ke kolom search buat besok

    echo "$(date) - checkout done" >> "$LOG"
    sleep 120  # cegah double-trigger di window toleransi yang sama
  fi

  sleep 30  # polling, bukan sleep panjang -- lihat catatan di atas
done
