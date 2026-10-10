# Onderdil Motor Indonesia

> Katalog & sistem penjualan sparepart (onderdil) motor OEM — Flutter + Supabase

**Muhammad Azfa Eka Satria — 23EO10001**

## Tentang Aplikasi

Aplikasi mobile berbasis Flutter yang berfungsi sebagai katalog dan sistem
penjualan sparepart motor OEM. Terintegrasi dengan backend Supabase untuk
autentikasi, database relasional, sinkronisasi data realtime, serta
penyimpanan file (foto produk & bukti pembayaran).

## Multi-Role

| Role | Hak Akses |
|---|---|
| **Customer** | Cari sparepart (TF-IDF), keranjang belanja cloud, checkout, upload bukti transfer, riwayat pesanan |
| **Staff Gudang** | Update stok fisik barang, kelola status pengiriman pesanan |
| **Admin Penuh** | CRUD produk (foto, harga, stok), verifikasi/tolak pembayaran, laporan penjualan + export CSV |

Keamanan data diterapkan dengan **Row Level Security (RLS)** di Supabase,
sehingga setiap role hanya dapat mengakses data sesuai haknya.

## Tech Stack

- **Frontend:** Flutter (Material Design 3, tema Racing Red)
- **Backend:** Supabase (Auth, Postgres, Realtime, Storage)
- **Fitur khusus:** Pencarian TF-IDF, keranjang realtime, ekspor CSV

## Cara Menjalankan

1. Install Flutter SDK & NDK Android
2. Buat file `config/dev.json` berisi credential Supabase kamu:
   ```json
   {
     "SUPABASE_URL": "isi-url-supabase",
     "SUPABASE_ANON_KEY": "isi-anon-key"
   }