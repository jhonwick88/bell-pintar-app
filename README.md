# 🔔 Bell Pintar - Client Application (Flutter)
> **Aplikasi Antarmuka Multiplatform (Windows Desktop & Android Mobile)**  
> *Bagian dari ekosistem otomatisasi bel sekolah cerdas "Bell Pintar" by Pintar Labs.*

---

## 📱 Fitur Aplikasi Klien
Aplikasi ini merupakan antarmuka interaktif bagi guru piket dan staf Tata Usaha (TU) sekolah untuk:
- **Jadwal & Preset:** Manajemen jadwal bel harian dengan *TimePicker* visual, dukungan pola **5 Hari Sekolah** (Senin–Jumat) & **6 Hari Sekolah** (Senin–Sabtu), duplikasi jadwal, serta tombol *Kosongkan Hari Ini*.
- **Swipe Action Mobile:** Pada perangkat HP/layar kecil, jadwal dapat digeser ke kanan untuk opsi edit dan hapus yang mulus.
- **Pustaka Nada (138+ Audio):** Memutar, menguji coba (*Audio Preview*), dan menambah koleksi suara kustom sekolah di menu **Bank Suara** (`.mp3` / `.wav`).
- **Studio Pengumuman (TTS):** Siaran langsung teks-ke-suara, fitur **Dikte Suara (Speech-to-Text)** tanpa mengetik, serta **CRUD Template Pengumuman Cepat** lengkap dengan pilihan nada chime pembuka.
- **Remote Mobile & QR Pairing:** Kendali bel jarak jauh via HP Android dengan koneksi LAN/Wi-Fi via Scan QR Code instan (`bellpintar://pair?url=...`).
- **Pengaturan & Identitas Sekolah:** Konfigurasi nama sekolah resmi, aktivasi lisensi, kontrol jeda relay amplifier, serta riwayat audit log.
- **About & Kontak Developer:** Bagian profil aplikasi serta tombol langsung chat WhatsApp dan Email ke tim pengembang Pintar Labs.

---

## 🔑 Akun & PIN Default
- **Admin TU:** `123456` *(Akses penuh manajemen jadwal, audio kustom, lisensi, dan pairing perangkat)*
- **Guru Piket:** `7890` *(Akses pemicu bel darurat, penggantian preset jadwal, dan siaran pengumuman)*

---

## 📖 Panduan Penggunaan Lengkap
Untuk panduan operasional lengkap, alur pengunggahan audio AI / rekaman mandiri, panduan kompatibilitas Windows 7/8/10/11, serta pemecahan masalah (FAQ), silakan merujuk ke dokumentasi utama:
👉 **[server/README.md](file:///h:/FlutterProject/bell_pintar/server/README.md)**

---

## 🛠️ Pengembangan & Build

### 1. Menjalankan Mode Development
```bash
# Di platform Windows Desktop
flutter run -d windows

# Di perangkat Android / Emulator
flutter run -d android
```

### 2. Membangun Paket Rilis (Production Build)
```bash
# Build untuk Windows Portable / Installer
flutter build windows --release

# Build APK untuk HP Android Guru / Sekolah
flutter build apk --release
```

---

## 💼 Kontak & Layanan Kustom Developer (Pintar Labs)
- 📱 **WhatsApp:** [0821-3293-5169](https://wa.me/6282132935169?text=Halo%20Developer%20Bell%20Pintar,%20saya%20tertarik%20untuk%20konsultasi%20custom%20fitur%20/%20pembuatan%20aplikasi.)
- ✉️ **Email:** [labspintar@gmail.com](mailto:labspintar@gmail.com)

---
*© Bell Pintar by Pintar Labs — Solusi Digital Sekolah Pintar Indonesia.*
