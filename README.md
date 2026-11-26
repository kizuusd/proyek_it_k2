# Tracking Sales CV Maju Bersama

Aplikasi Flutter untuk Sales, Admin, dan Owner dengan backend Node.js dan MySQL. Mulai dari direktori yang berisi `pubspec.yaml`.

## 1. Siapkan alat

- Flutter 3.47 atau lebih baru dengan Dart 3.13 atau lebih baru. Versi yang dipakai saat verifikasi adalah Flutter 3.47.2.
- Node.js 22 atau lebih baru dan npm.
- MySQL atau MariaDB. Windows bisa memakai layanan MySQL dari XAMPP atau Laragon.
- Untuk Android, pasang Android SDK Platform 36, Platform-Tools (ADB), dan NDK 28.2.13676358 dari Android Studio. Jalankan `flutter doctor -v` untuk memeriksa toolchain dan `flutter doctor --android-licenses` jika lisensi Android belum diterima. Aktifkan Developer Mode di Windows jika Flutter meminta dukungan symlink plugin.

## 2. Siapkan database

Jalankan MySQL. Untuk **setup pertama pada database lokal baru**, impor [database/db_tracking_sales.sql](database/db_tracking_sales.sql). File ini membuat database `db_tracking_sales`, tabel, dan akun demo. **Impor ulang mengganti tabel dan data yang sudah ada.** Untuk database proyek yang sudah dipakai, buat cadangan dan jalankan backend agar migrasi skema yang tersedia diterapkan.

Dari PowerShell di root proyek:

```powershell
mysql.exe --default-character-set=utf8mb4 -u root -p -e "source database/db_tracking_sales.sql"
```

Jika MySQL lokal menggunakan password kosong, hapus opsi `-p`. Jika `mysql.exe` belum ada di PATH, gunakan lokasinya, misalnya `& 'C:/xampp/mysql/bin/mysql.exe'`, atau impor file lewat phpMyAdmin.

## 3. Jalankan backend

Buka terminal PowerShell di root proyek:

```powershell
cd backend
Copy-Item .env.example .env
npm.cmd ci
npm.cmd start
```

Salin `.env.example` saat setup pertama. Bila `backend/.env` sudah ada, gunakan konfigurasi yang ada dan sesuaikan `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, serta `DB_NAME` dengan MySQL di komputer masing-masing. Di macOS atau Linux, gunakan `cp .env.example .env`, `npm ci`, dan `npm start`.

Cek backend dari komputer yang menjalankannya:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/api/health
```

Respons `status: OK` berarti backend terhubung ke MySQL. Jika server berhenti saat startup, baca pesan terminal untuk mengetahui apakah port terpakai, koneksi ditolak, atau skema belum terpasang.

## 4. Jalankan Flutter

Buka terminal kedua di root proyek:

```powershell
flutter pub get
flutter devices
```

Pilih salah satu cara menjalankan aplikasi:

| Target | Perintah |
| --- | --- |
| Android lewat USB | Aktifkan USB debugging dan setujui prompt di ponsel. Jalankan `adb devices`, lalu `adb reverse tcp:8000 tcp:8000` dan `flutter run`. |
| Android Emulator bawaan Android Studio | Jalankan emulator, lalu `flutter run`. Backend di komputer dapat diakses lewat `10.0.2.2:8000`. |
| Chrome | Jalankan `flutter run -d chrome`. |

Jika beberapa perangkat tersambung, pilih perangkat dengan `adb -s ID_PERANGKAT reverse tcp:8000 tcp:8000` dan `flutter run -d ID_PERANGKAT`. ADB tersedia di folder `platform-tools` pada Android SDK.

Untuk server atau port yang berbeda, tetapkan URL API secara eksplisit. Sertakan akhiran `/api`.

```powershell
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8001/api
```

Untuk contoh port 8001 lewat USB, jalankan juga `adb reverse tcp:8001 tcp:8001`. Untuk emulator, gunakan `10.0.2.2` sebagai host. Flutter akan membuat `android/local.properties` berdasarkan SDK di komputer yang menjalankan build.

Untuk uji LAN, setel `HOST=0.0.0.0` di `backend/.env`, mulai ulang backend, lalu masukkan alamat IP komputer server pada `API_BASE_URL`. Komputer dan ponsel perlu berada di jaringan yang sama, dan firewall perlu mengizinkan port yang dipilih. Gunakan akun demo hanya untuk pengujian lokal.

## Akun dan pengujian

Login email tersedia lewat akun demo `owner@majubersama.com`, `admin@majubersama.com`, dan `sales@majubersama.com`. Kata sandi seed ada di [panduan database](database/README.md). Pengujian kamera dan lokasi dilakukan di Android setelah memberikan izin saat diminta.

```powershell
flutter test
```
