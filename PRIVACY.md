<!--
SPDX-FileCopyrightText: 2019-Present Christian Kußowski
SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
SPDX-FileCopyrightText: 2026-Present POCIND MESSENGER contributors

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Kebijakan Privasi POCIND MESSENGER

POCIND MESSENGER adalah aplikasi klien Matrix yang dikelola oleh POCIND Indonesia
dan merupakan modifikasi dari FluffyChat. Kebijakan ini menjelaskan data apa yang
diproses oleh aplikasi dan ke mana data tersebut dikirim.

## Data yang diproses

- **Akun dan pesan.** Saat Anda masuk, aplikasi terhubung ke homeserver
  `matrix.pocindonesia.com`. Pesan, profil, daftar kontak, dan lampiran disimpan
  pada homeserver tersebut dan tunduk pada kebijakan pengelola server.
- **Tanpa enkripsi end-to-end.** Fitur E2EE dinonaktifkan pada aplikasi ini, sehingga
  isi pesan dapat dibaca oleh pengelola homeserver. Jangan gunakan aplikasi ini untuk
  data rahasia atau sensitif.
- **Data lokal di perangkat.** Token sesi, cache pesan dan media, serta preferensi
  aplikasi disimpan di perangkat Anda. Keluar dari akun akan menghapus data lokal
  tersebut.
- **Notifikasi push.** Token push perangkat dikirim ke homeserver POCIND agar
  notifikasi dapat diteruskan ke perangkat. Tidak ada gateway push pihak ketiga.
- **Laporan error.** Aplikasi tidak mengirim laporan error secara otomatis. Jika
  fitur laporan error diaktifkan dan Anda menekan tombol lapor, aplikasi hanya
  membuka halaman GitHub POCIND; tidak ada data yang dikirim tanpa tindakan Anda.
- **Pemeriksaan pembaruan.** Pada Windows, aplikasi memeriksa versi terbaru ke GitHub
  API repositori POCIND paling banyak sekali sehari. Pemeriksaan ini dapat dimatikan
  di pengaturan.

Aplikasi ini tidak menggunakan analytics, pelacakan iklan, maupun layanan pihak
ketiga lainnya untuk memantau penggunaan.

## Izin perangkat

Kamera, mikrofon, lokasi, kontak, penyimpanan, dan notifikasi hanya diakses ketika
Anda menggunakan fitur yang membutuhkannya (misalnya mengirim foto, panggilan suara,
atau berbagi lokasi).

## Retensi dan penghapusan

Data lokal dihapus saat Anda keluar dari akun atau menghapus aplikasi. Data pada
homeserver dikelola oleh POCIND Indonesia; hubungi pengelola server untuk permintaan
penghapusan data akun.

## Perubahan kebijakan

Perubahan kebijakan ini akan dipublikasikan di repositori
<https://github.com/POC-INDONESIA/messenger>.

## Kontak

Pertanyaan tentang privasi dapat disampaikan melalui
<https://github.com/POC-INDONESIA/messenger/issues>.

## Tentang FluffyChat

POCIND MESSENGER dibangun di atas FluffyChat (AGPL-3.0-or-later). Kebijakan privasi
ini hanya berlaku untuk POCIND MESSENGER, bukan untuk proyek FluffyChat.
