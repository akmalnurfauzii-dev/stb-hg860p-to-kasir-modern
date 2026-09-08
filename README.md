# STB HG860P to Sistem Kasir Modern

Sistem kasir "auto-scan" untuk Android TV Box (STB) yang di-root, dibuat
tanpa PC/laptop khusus, tanpa aplikasi POS berbayar, dan tanpa hardware
tambahan selain yang sudah ada di kedai kelontong biasa.

Barcode ditembak dari scanner USB → langsung masuk keranjang di Loyverse
POS, tanpa perlu klik mouse sama sekali — persis seperti pengalaman kasir
di minimarket modern. Setiap hari jam 23:59, sistem juga otomatis
menutup transaksi yang tertinggal (scan tapi lupa dibayar).

![status](https://img.shields.io/badge/status-production-brightgreen)
![platform](https://img.shields.io/badge/platform-Android%20TV-blue)
![license](https://img.shields.io/badge/license-MIT-yellow)

---

## Latar belakang

Kedai Vitamart adalah minimarket kecil di Purbalingga, Jawa Tengah, yang
menjual es teh dan minuman kemasan. Untuk kasir, yang tersedia hanya:

- STB Android TV **HG860P**, sudah di-root
- TV biasa sebagai monitor
- Mouse wireless
- Scanner barcode USB generik (terbaca sebagai keyboard/HID)
- **Tanpa PC atau laptop** untuk operasional harian

Aplikasi POS gratis yang tersedia (Loyverse, Kasir Pintar, dll) semuanya
mengharuskan kasir mengklik kolom pencarian secara manual sebelum scanner
bisa terbaca — dan begitu discan, soft keyboard Android (Gboard) langsung
menutupi separuh layar transaksi. Tidak ada versi Android TV dari
aplikasi-aplikasi ini yang mendukung "global barcode listener" bawaan.

Belakangan muncul juga masalah kedua: karena scan jadi semudah ini,
keluarga di rumah kadang scan barang cuma untuk cek harga — tiket
menumpuk di Loyverse tapi tidak pernah dibayar. Untuk itu ditambahkan
sistem auto-checkout yang menutup transaksi tertinggal setiap jam 23:59.

Project ini adalah solusi custom di level sistem (bukan mengganti
aplikasi kasirnya) untuk menutup kedua gap tersebut.

## Cara kerja

```
Scanner USB (HID)
      │
      ▼
/dev/input/eventX  ──▶  getevent (baca event mentah)
      │
      ▼
auto_scan_v3.sh (deteksi pola scan selesai)
      │
      ▼
input tap (simulasi tap ke koordinat Loyverse)
      │
      ▼
Barang otomatis masuk ke keranjang


auto_checkout.sh (polling tiap 30 detik, cek jam 23:59)
      │
      ▼
input tap Charge → Cash → Confirm
      │
      ▼
Transaksi tertinggal otomatis ditutup
```

Tiga bagian utama:

| File | Fungsi |
|---|---|
| [`scripts/auto_scan_v3.sh`](scripts/auto_scan_v3.sh) | Loop utama: dengarkan scanner, deteksi barcode selesai, tap otomatis ke hasil pencarian |
| [`scripts/auto_checkout.sh`](scripts/auto_checkout.sh) | Polling tiap 30 detik; pada jam 23:59, otomatis menyelesaikan transaksi yang tertinggal |
| [`scripts/start_scan.sh`](scripts/start_scan.sh) | Boot wrapper (via Termux:Boot) — semua otomatis jalan begitu STB dinyalakan, tanpa laptop |

Karena STB ini tidak punya touchscreen (semua interaksi lewat mouse),
koordinat tap dicari lewat `uiautomator dump` dan trial-and-error `input
tap`, bukan lewat sentuhan langsung di layar.

## Yang dibutuhkan

- Android TV Box yang bisa di-root (unlocked bootloader + Magisk atau
  sejenisnya)
- [Termux](https://github.com/termux/termux-app) + [Termux:Boot](https://github.com/termux/termux-boot)
  + Termux:API (untuk wake-lock)
- Scanner barcode USB mode HID/keyboard (plug and play, tanpa driver)
- Aplikasi kasir Android apa pun yang punya kolom pencarian barcode
  (dikembangkan & diuji dengan Loyverse POS)

## Instalasi singkat

```bash
git clone https://github.com/akmalnurfauzii-dev/stb-hg860p-to-kasir-modern.git
cd stb-hg860p-to-kasir-modern
```

Lihat panduan lengkap di [`docs/setup-guide.md`](docs/setup-guide.md) —
termasuk cara mencari koordinat tombol, whitelist baterai, dan
troubleshooting.

Ringkasnya:

```bash
# 1. Push script ke STB (dari laptop via ADB over WiFi)
adb push scripts/auto_scan_v3.sh /sdcard/auto_scan_v3.sh
adb push scripts/auto_checkout.sh /sdcard/auto_checkout.sh
adb shell su -c "chmod +x /sdcard/auto_scan_v3.sh /sdcard/auto_checkout.sh"

# 2. Whitelist Termux dari battery optimization (penting!)
adb shell dumpsys deviceidle whitelist +com.termux
adb shell dumpsys deviceidle whitelist +com.termux.boot

# 3. Pasang boot wrapper (langsung dari Termux di STB)
mkdir -p ~/.termux/boot
cp start_scan.sh ~/.termux/boot/start_scan.sh
chmod +x ~/.termux/boot/start_scan.sh

# 4. Reboot STB — semuanya jalan otomatis
```

## Yang perlu disesuaikan sendiri

Koordinat dan device path di script ini **spesifik untuk setup penulis**
(resolusi layar, layout Loyverse, dan device scanner tertentu). Kamu
hampir pasti perlu mencari ulang nilai-nilai ini untuk setupmu sendiri:

- `SCANNER_DEV` (path `/dev/input/eventX`) — cari lewat `getevent -pl`
- Semua koordinat `input tap X Y` — cari lewat `uiautomator dump` atau
  trial-and-error
- Jam target checkout (default 23:59) di `auto_checkout.sh`

Detail caranya ada di [`docs/setup-guide.md`](docs/setup-guide.md).

## Tantangan teknis yang dihadapi

- **SELinux Enforcing** memblokir akses langsung ke `/dev/input/*` meski
  sudah root — perlu `su` dengan cara yang tepat, bukan `setenforce`
  sembarangan
- **STB tanpa touchscreen** membuat metode "Pointer Location" tidak bisa
  dipakai untuk mencari koordinat secara visual — solusinya pindah ke
  `uiautomator dump`
- **NullKeyboard sebagai default IME** untuk mencegah Gboard menutupi
  layar transaksi saat scanner mengirim keystroke
- **Read-only filesystem** saat membuat file di `~/.termux/boot/` kalau
  keliru menjalankan perintah dalam mode root (`#`) — folder home Termux
  harus dibuat sebagai user biasa (`$`), bukan root
- **Sleep panjang dibunuh Doze Mode** — percobaan pertama untuk
  auto-checkout menghitung selisih detik ke 23:59 lalu `sleep` sekali
  sepanjang itu; proses ini konsisten mati sebelum waktunya karena
  dianggap "menganggur" oleh Android. Solusinya diganti ke pola
  **polling 30 detik** dikombinasikan dengan wake-lock dan whitelist
  baterai — lihat detail di
  [`docs/setup-guide.md`](docs/setup-guide.md#kenapa-polling-30-detik-bukan-sleep-panjang-sekali-tembak)
- **CRLF vs LF** — script yang diedit di Notepad Windows lalu di-push ke
  STB memicu `syntax error: unexpected 'done'` karena karakter `\r`
  dibaca sebagai bagian perintah oleh shell Android
- **Boot timing** — script harus menunggu (`sleep 25`) sampai Android dan
  Loyverse benar-benar siap sebelum mulai menyimulasikan tap

## Kontribusi

Menemukan bug, punya versi koordinat untuk STB lain, atau ingin
menambahkan dukungan aplikasi kasir selain Loyverse? Pull request dan
issue terbuka untuk siapa saja.

## Lisensi

MIT — bebas dipakai, dimodifikasi, dan dibagikan. Lihat [`LICENSE`](LICENSE).

---

*Dibuat oleh [Akmal](https://github.com/akmalnurfauzii-dev), pemilik &
operator Kedai Vitamart, Purbalingga.*
