#!/data/data/com.termux/files/usr/bin/sh
# start_scan.sh
#
# Boot wrapper untuk Termux:Boot. Menjalankan seluruh sistem kasir
# otomatis setiap kali STB dinyalakan ulang -- tanpa perlu laptop
# atau ADB manual lagi.
#
# Lokasi file ini harus di:
#   ~/.termux/boot/start_scan.sh
# (yaitu /data/data/com.termux/files/home/.termux/boot/start_scan.sh)
#
# Jangan lupa `chmod +x` setelah membuat file ini.

sleep 25   # beri waktu Android & Loyverse selesai boot dulu

# Matikan soft keyboard bawaan, ganti ke NullKeyboard supaya scan
# barcode tidak memicu Gboard menutupi layar transaksi.
su -c "settings put secure default_input_method com.wparam.nullkeyboard/.NullKeyboard"

# Jalankan sistem auto-scan (foreground, karena ini proses utama)
su -c "sh /sdcard/auto_scan_v3.sh"

# Jalankan penjaga auto-checkout jam 23:59 di background
su -c "sh /sdcard/auto_checkout.sh &"
