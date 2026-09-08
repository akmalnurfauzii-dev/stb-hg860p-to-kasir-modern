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
5. Install juga Termux:API untuk fitur wake-lock:
   ```bash
   pkg install termux-api -y
   ```

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

> Kalau resolusi layar berubah (ganti TV/monitor), semua koordinat ini
> harus dicari ulang dari nol.

## 6. Push script ke STB

```cmd
adb push scripts/auto_scan_v3.sh /sdcard/auto_scan_v3.sh
adb push scripts/auto_checkout.sh /sdcard/auto_checkout.sh
adb shell su -c "chmod +x /sdcard/auto_scan_v3.sh"
adb shell su -c "chmod +x /sdcard/auto_checkout.sh"
```

Edit dulu koordinat dan `SCANNER_DEV` di kedua file sebelum di-push,
sesuaikan dengan hasil langkah 4 dan 5.

> **Penting soal line ending:** kalau script ditulis/diedit di Notepad
> Windows lalu di-push ke STB, biasanya tersimpan dengan format CRLF
> (`\r\n`). Shell Android (mksh/toybox) membaca `\r` sebagai bagian dari
> perintah, menyebabkan error aneh seperti
> `syntax error: unexpected 'done'` padahal scriptnya terlihat benar.
> Solusi paling aman: tulis/edit script langsung di Termux (format Unix
> otomatis), atau jalankan `sed -i 's/\r$//' namafile.sh` di Termux
> setelah push dari Windows.

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
su -c "termux-wake-lock" 2>/dev/null || true
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

## 9. Whitelist battery optimization (WAJIB, jangan dilewati)

Ini langkah yang paling sering jadi penyebab "script sudah benar tapi
tetap tidak jalan otomatis". Android (dan lebih parah lagi, banyak STB
custom vendor) sangat agresif membunuh proses background yang dianggap
"menganggur", termasuk proses shell Termux yang sedang `sleep`.

Dari laptop:

```cmd
adb shell dumpsys deviceidle whitelist +com.termux
adb shell dumpsys deviceidle whitelist +com.termux.boot
```

Atau manual di STB: **Setelan → Aplikasi → Termux → Baterai → "Tanpa
batasan"**, ulangi untuk Termux:Boot.

## 10. Uji manual sebelum reboot

```bash
sh ~/.termux/boot/start_scan.sh
```

Pastikan tidak ada error yang muncul, dan sistem benar-benar merespons
scan barcode seperti yang diharapkan.

## 11. Reboot dan tes akhir

Matikan dan nyalakan ulang STB (cabut-colok power). Tunggu ±25 detik.
Buka Loyverse, coba tembak barcode — barang harus otomatis masuk ke
keranjang tanpa klik apa pun.

---

## Kenapa polling 30 detik, bukan sleep panjang sekali tembak

Versi awal `auto_checkout.sh` menghitung selisih detik ke jam 23:59 lalu
`sleep` sekali sepanjang itu (bisa berjam-jam). Ini terlihat efisien di
atas kertas, tapi gagal total di praktik: Android (lewat Doze Mode dan
app-killer bawaan vendor STB) cenderung membunuh proses yang dianggap
"menganggur" dalam `sleep` jangka panjang, terutama saat layar mati atau
sistem idle lama.

Solusi yang terbukti jalan: ganti jadi **polling** — script bangun tiap
30 detik, cek apakah sekarang sudah masuk jendela waktu target
(23:59:00 sampai 23:59:90, ada toleransi 90 detik), lalu tidur lagi kalau
belum. Karena proses "bangun" secara berkala, sistem tidak menganggapnya
menganggur dan cenderung tidak membunuhnya — apalagi setelah dikombinasi
dengan wake-lock dan whitelist baterai di langkah 9.

## Troubleshooting

| Masalah | Kemungkinan penyebab |
|---|---|
| `getevent: Permission denied` walau sudah `su` | SELinux Enforcing memblokir `/dev/input/*` |
| `mkdir: Read-only file system` di `~/.termux/boot` | Sedang dalam mode root (`#`), harus `exit` dulu ke mode user (`$`) |
| `syntax error: unexpected 'done'` padahal script terlihat benar | File tersimpan dalam format Windows (CRLF). Jalankan `sed -i 's/\r$//' namafile.sh` |
| `arithmetic expression: expecting ')'` saat parsing jam/menit | Shell Android tidak mendukung prefix `10#` untuk angka; pakai `${H#0}` untuk buang nol di depan |
| Script auto-checkout tidak pernah trigger jam 23:59 | Kemungkinan besar proses dibunuh Android sebelum sempat jalan — cek `pgrep -f auto_checkout` untuk pastikan proses masih hidup, pastikan whitelist baterai (langkah 9) sudah dilakukan, dan cek `checkout_log.txt` untuk lihat kapan persis proses berhenti |
| Termux hang / tidak responsif setelah jalankan script manual | Lupa menambahkan `&` di akhir perintah, sehingga script mengambil alih terminal secara foreground. Jalankan dengan `su -c "sh /sdcard/auto_checkout.sh &"` |
| Tap tidak kena tombol yang benar | Koordinat sudah tidak sesuai — resolusi berubah, atau layout Loyverse update |
| Boot wrapper tidak jalan otomatis | Termux:Boot belum pernah dibuka manual sekali, atau permission Magisk belum di-grant |
| Gboard masih muncul walau NullKeyboard aktif | Aplikasi kasir memanggil keyboard secara eksplisit lewat kode — coba cek apakah ada opsi *"scan mode"* khusus di aplikasi tersebut |

### Cara cek proses masih hidup

```bash
pgrep -f auto_checkout
```
Kalau keluar angka (PID), proses masih berjalan. Kalau kosong, proses
sudah mati dan perlu dijalankan ulang manual atau dicari kenapa boot
wrapper-nya gagal.

### Cara baca log

`auto_checkout.sh` menulis log ke `/sdcard/checkout_log.txt` setiap 30
detik. Ambil dari laptop:

```cmd
adb pull /sdcard/checkout_log.txt
```

Baris terakhir di file itu menunjukkan kapan persis proses berhenti
menulis log — itu kira-kira waktu proses dibunuh sistem (kalau memang
itu masalahnya).
