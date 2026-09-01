#!/system/bin/sh
# auto_scan_v3.sh
#
# Mendengarkan input mentah dari scanner barcode USB (dibaca sebagai
# HID keyboard oleh Android) lewat getevent, mendeteksi kapan sebuah
# scan selesai (jeda idle setelah aliran keystroke cepat), lalu
# menyimulasikan tap ke tombol hasil pencarian di Loyverse POS.
#
# Ganti /dev/input/eventX sesuai device scanner kamu sendiri.
# Cara cek: jalankan `getevent -pl` lalu cari device dengan nama
# yang mengarah ke scanner/keyboard (biasanya HID <vendor>:<product>).
#
# Ganti juga koordinat tap sesuai layout Loyverse & resolusi layar kamu.
# Cara cari koordinat: lihat docs/setup-guide.md bagian "Mencari koordinat".

sleep 1
input tap 1208 56   # tap awal ke kolom search biar fokus siap nerima input scanner
sleep 1

active=0
idle_count=0

getevent -l /dev/input/event7 | while true; do
  if read -t 2 -r line; then
    active=1
    idle_count=0
  else
    if [ "$active" = "1" ]; then
      active=0
      idle_count=0
      sleep 0.2
      input tap 134 223    # tap ke hasil pencarian pertama
      sleep 0.3
      input tap 1208 56    # balik fokus ke kolom search buat scan berikutnya
    else
      idle_count=$((idle_count+1))
      if [ "$idle_count" -ge 2 ]; then
        idle_count=0
        input tap 1208 56  # jaga-jaga fokus nggak hilang saat idle lama
      fi
    fi
  fi
done
