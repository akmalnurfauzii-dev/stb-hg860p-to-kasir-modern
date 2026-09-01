# Panduan Setup Lengkap

Panduan ini mengasumsikan STB kamu sudah di-root (bootloader unlocked +
akses `su`), dan kamu punya laptop yang bisa dihubungkan lewat ADB over
WiFi (tidak perlu kabel data ke STB).

## 1. Siapkan Termux di STB

Karena STB Android TV biasanya tidak punya akses Play Store yang penuh
atau menu keyboard-picker yang lengkap, install Termux lewat sideload:

1. Download APK Termux dari [GitHub releases resmi](https://github.com/termux/termux-app/releases)
   — pilih varian `universal.apk` untuk kompatibilitas paling luas
2. Install lewat file manager apa pun yang sudah ada di STB
3. Install juga [Termux:Boot](https://github.com/termux/termux-boot/releases)
   dengan cara yang sama
4. Buka Termux:Boot **sekali** (boleh langsung tertutup sendiri) — ini
   mendaftarkan dia sebagai boot receiver ke sistem

## 2. Aktifkan ADB over WiFi

Di dalam Termux STB:

```bash
su
setprop service.adb.tcp.port 5555
stop adbd
start adbd
ip addr show wlan0   # catat alamat "inet x.x.x.x" — itu IP STB kamu
```

Dari laptop:

```cmd
adb connect <IP_STB>:5555
adb devices
```

Pastikan statusnya `device`, bukan `unauthorized` atau `offline`.

## 3. Matikan Gboard yang selalu muncul saat scan

```cmd
adb shell settings put secure show_ime_with_hard_keyboard 0
```

Jika masih muncul juga (karena aplikasi kasir memanggil keyboard secara
eksplisit, bukan lewat perilaku default Android), install
[NullKeyboard](https://github.com/wParam/NullKeyboard) dan jadikan
default IME:

```cmd
adb shell settings put secure default_input_method com.wparam.nullkeyboard/.NullKeyboard
```

Untuk mengembalikan ke Gboard biasa (misalnya untuk mengetik di browser):

```cmd
adb shell settings put secure default_input_method com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME
```

## 4. Cari device scanner kamu

Barcode scanner USB biasanya terbaca sebagai HID keyboard oleh Android.
Di Termux (dengan `su`):

```bash
su
getevent -pl
```

Scroll hasilnya, cari device dengan nama yang mengarah ke scanner
(biasanya format `HID <vendor_id>:<product_id>`). Catat path
`/dev/input/eventX`-nya — itu yang dipakai di `SCANNER_DEV` pada kedua
script.

> **Catatan SELinux:** kalau `getevent` gagal dengan
> `Permission denied` meski sudah `su`, itu bukan salah ketik — itu
> SELinux Enforcing yang memblokir akses ke `/dev/input/*` di beberapa
> ROM custom. Beberapa STB mengizinkan `setenforce 0` untuk melonggarkan
> ini sementara; sebagian lain mengunci ini secara permanen di level
> vendor dan tidak bisa dilonggarkan sama sekali.

## 5. Mencari koordinat tombol (tanpa touchscreen)

Karena STB dioperasikan lewat mouse (tidak ada sentuhan langsung ke
layar), metode visual seperti "Pointer Location" di Developer Options
tidak banyak membantu. Cara paling presisi:

```cmd
adb shell uiautomator dump /sdcard/window_dump.xml
adb pull /sdcard/window_dump.xml
```

Buka file `window_dump.xml` dengan text editor apa pun, cari teks tombol
yang kamu incar (misalnya `text="BAYAR"`). Kamu akan menemukan atribut
`bounds`, contoh:

```
bounds="[875,1450][1580,1550]"
```

Format `bounds` adalah `[x1,y1][x2,y2]` — sudut kiri-atas dan
kanan-bawah kotak tombol. Hitung titik tengahnya:

```
X = (x1 + x2) / 2
Y = (y1 + y2) / 2
```

Uji koordinatnya langsung dari laptop sebelum dimasukkan ke script:

```cmd
adb shell input tap <X> <Y>
```

Ulangi proses dump untuk setiap layar/tombol berbeda (kolom search, hasil
pencarian pertama, tombol Bayar, metode Cash, tombol konfirmasi, dst).

## 6. Push script ke STB

```cmd
adb push scripts/auto_scan_v3.sh /sdcard/auto_scan_v3.sh
adb push scripts/auto_checkout.sh /sdcard/auto_checkout.sh
adb shell su -c "chmod +x /sdcard/auto_scan_v3.sh"
adb shell su -c "chmod +x /sdcard/auto_checkout.sh"
```

Edit dulu koordinat dan `SCANNER_DEV` di kedua file sebelum di-push,
sesuaikan dengan hasil langkah 4 dan 5.

## 7. Pasang boot wrapper

Ini **wajib dilakukan langsung di Termux STB**, bukan lewat ADB shell
biasa dari laptop — kalau lewat `adb shell` biasa akan kena
`Permission denied` karena folder Termux hanya bisa ditulis oleh
prosesnya sendiri.

Buka Termux di STB, pastikan prompt kamu adalah `$` (user biasa),
**bukan** `#` (root) — kalau masih `#`, ketik `exit` dulu. Ini penting
karena di mode root, `~` mengarah ke `/` bukan ke home Termux.

```bash
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/start_scan.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
sleep 25
su -c "settings put secure default_input_method com.wparam.nullkeyboard/.NullKeyboard"
su -c "sh /sdcard/auto_scan_v3.sh"
su -c "sh /sdcard/auto_checkout.sh &"
EOF
chmod +x ~/.termux/boot/start_scan.sh
```

Verifikasi:

```bash
cat ~/.termux/boot/start_scan.sh
ls -la ~/.termux/boot/
```

Pastikan ada tanda `x` (executable) di izin file tersebut.

## 8. Grant permission di Magisk

Buka Magisk Manager → menu Superuser → pastikan `Termux` dan
`Termux:Boot` berstatus **Grant** (toggle aktif), supaya tidak ada popup
konfirmasi yang menghalangi eksekusi otomatis saat boot.

## 9. Uji manual sebelum reboot

```bash
sh ~/.termux/boot/start_scan.sh
```

Pastikan tidak ada error yang muncul, dan sistem benar-benar merespons
scan barcode seperti yang diharapkan.

## 10. Reboot dan tes akhir

Matikan dan nyalakan ulang STB (cabut-colok power). Tunggu ±25 detik.
Buka Loyverse, coba tembak barcode — barang harus otomatis masuk ke
keranjang tanpa klik apa pun.

## Troubleshooting singkat

| Masalah | Kemungkinan penyebab |
|---|---|
| `getevent: Permission denied` walau sudah `su` | SELinux Enforcing memblokir `/dev/input/*` |
| `mkdir: Read-only file system` di `~/.termux/boot` | Sedang dalam mode root (`#`), harus `exit` dulu ke mode user (`$`) |
| Tap tidak kena tombol yang benar | Koordinat sudah tidak sesuai — resolusi berubah, atau layout Loyverse update |
| Boot wrapper tidak jalan otomatis | Termux:Boot belum pernah dibuka manual sekali, atau permission Magisk belum di-grant |
| Gboard masih muncul walau NullKeyboard aktif | Aplikasi kasir memanggil keyboard secara eksplisit lewat kode — coba cek apakah ada opsi *"scan mode"* khusus di aplikasi tersebut |
