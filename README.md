# 🔔 Bell Pintar - Client Application (Flutter)
> **Aplikasi Antarmuka Multiplatform (Android Tablet/HP, Windows Desktop, & Web Showcase)**  
> *Bagian dari ekosistem otomatisasi bel sekolah cerdas & penyiaran modern "Bell Pintar" by Pintar Labs.*

---

## 🚀 Coba Versi Demo Interaktif (Standalone Showcase)

Bagi calon pembeli, sekolah, atau yayasan yang ingin mencoba dan menguji coba fitur **Bell Pintar** secara langsung tanpa instalasi server PC:

### ✨ Keunggulan Versi Demo:
1. **100% Standalone (Tanpa PC Server):** Anda dapat langsung mencoba seluruh antarmuka, pembuatan jadwal kustom, bank suara 138+, simulasi sirine, dan studio pengumuman TTS langsung dari tablet Android, HP, browser web, ataupun laptop.
2. **Preset Jadwal Lengkap:** Tersedia simulasi jadwal *Reguler 5 Hari*, *Jadwal Khusus Hari Jumat*, dan *Pekan Penilaian Akhir (Ujian)*.
3. **Studio Pengumuman TTS & Dikte Suara:** Menguji coba pengetikan pengumuman darurat, pesan suara, dan template chime pembuka.
4. **Mudah Dipresentasikan:** Cocok untuk sales/demo keliling sekolah hanya dengan membawa satu tablet Android.

### 📲 Cara Masuk ke Mode Demo:
1. Buka aplikasi **Bell Pintar**.
2. Pada layar koneksi server / PIN login, klik tombol:  
   👉 **`🚀 Coba Mode Demo (Tanpa Server)`**.
3. Aplikasi akan langsung membuka seluruh antarmuka penuh dalam mode simulasi interaktif.

---

## ⚖️ Perbandingan Versi Demo vs Paket Resmi Sekolah (Full System)

| Fitur / Kemampuan | Versi Demo (Showcase / Tablet) | Paket Resmi Bell Pintar (Full Edition) |
| :--- | :---: | :---: |
| **Tujuan Penggunaan** | Presentasi & Uji Coba UI | Operasional Harian Sekolah Resmi |
| **Perangkat Utama** | Tablet Android / HP / Web Browser | PC Server Desktop Windows (TU / Ruang Piket) |
| **Penyimpanan Data** | Simulasi In-Memory | Database SQLite Permanen di Server |
| **Koneksi Amplifier (TOA)** | ❌ Hanya speaker perangkat | ✅ Terhubung kabel AUX + USB Auto-Relay Controller |
| **Pemicu Bel Otomatis 24/7** | ❌ Simulasi visual countdown | ✅ Bunyi otomatis tepat detik tanpa henti |
| **Lisensi & Proteksi** | Lisensi Demo Preview | Lisensi Resmi Terikat HWID Mesin Sekolah |
| **Remote Guru Piket via Wi-Fi** | Simulasi | ✅ Scan QR Pairing HP Guru Piket |

---

## 📱 Fitur Aplikasi Klien
- **Jadwal & Preset:** Manajemen jadwal bel harian dengan *TimePicker* visual, dukungan pola **5 Hari Sekolah** (Senin–Jumat) & **6 Hari Sekolah** (Senin–Sabtu), duplikasi jadwal, serta tombol *Kosongkan Hari Ini*.
- **Swipe Action Mobile:** Pada perangkat HP/layar kecil, jadwal dapat digeser ke kanan untuk opsi edit dan hapus yang mulus.
- **Deteksi Otomatis IP Komputer (Smart LAN):** Dialog sambungan server LAN otomatis mendeteksi kartu jaringan aktif komputer (Ethernet / Wi-Fi) dan menyediakan pilihan 1-klik `[IP Komputer Ini]:8088` serta `localhost:8088`.
- **Pustaka Nada (138+ Audio):** Memutar, menguji coba (*Audio Preview*), dan menambah koleksi suara kustom sekolah di menu **Bank Suara** (`.mp3` / `.wav`).
- **Studio Pengumuman (TTS):** Siaran langsung teks-ke-suara, fitur **Dikte Suara (Speech-to-Text)** tanpa mengetik, serta **CRUD Template Pengumuman Cepat** lengkap dengan pilihan nada chime pembuka.
- **Remote Mobile & QR Pairing:** Kendali bel jarak jauh via HP Android dengan koneksi LAN/Wi-Fi via Scan QR Code instan (`bellpintar://pair?url=...`).
- **Pengaturan & Identitas Sekolah:** Konfigurasi nama sekolah resmi, aktivasi lisensi, kontrol jeda relay amplifier, serta riwayat audit log.

---

## 🔑 Akun & PIN Default
- **Admin TU:** `741147` *(Akses penuh manajemen jadwal, preset kustom, audio kustom, lisensi, dan pairing perangkat)*
- **Guru Piket:** `432234` *(Akses pemicu bel darurat, penggantian preset aktif, dan siaran pengumuman)*

---

## 📖 Panduan Penggunaan Lengkap Server
Untuk panduan operasional lengkap instalasi server komputer sekolah, modul USB relay amplifier, panduan kompatibilitas Windows 7/8/10/11, serta pemecahan masalah (FAQ):  
👉 **[server/README.md](file:///h:/FlutterProject/bell_pintar/server/README.md)**

---

## 🛠️ Pengembangan & Build

### 1. Menjalankan Mode Development
```bash
# Menjalankan di platform Web (Sangat bagus untuk demo online)
flutter run -d chrome

# Menjalankan di Android Tablet / HP
flutter run -d android

# Menjalankan di Windows Desktop
flutter run -d windows
```

### 2. Membangun Paket Rilis (Production Build)
```bash
# Build Web Showcase untuk diunggah ke hosting demo
flutter build web --release

# Build APK untuk Tablet Demo / HP Guru
flutter build apk --release

# Build untuk Windows Desktop
flutter build windows --release
```

---

## 💼 Pembelian Lisensi Resmi & Konsultasi Kustom (Pintar Labs)
Dapatkan paket lengkap **Bell Pintar (Software Server PC + Modul Auto Relay + Bank Suara 138+ & Update)** dengan menghubungi tim resmi Pintar Labs:

- 📱 **WhatsApp Official:** [0821-3293-5169](https://wa.me/6282132935169?text=Halo%20Tim%20Pintar%20Labs,%20saya%20tertarik%20membeli%20lisensi%20resmi%20Bell%20Pintar%20Sekolah.)
- ✉️ **Email:** [labspintar@gmail.com](mailto:labspintar@gmail.com)

---
*© Bell Pintar by Pintar Labs — Solusi Digital Otomatisasi Sekolah Pintar Indonesia.*
