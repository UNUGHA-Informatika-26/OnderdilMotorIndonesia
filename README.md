# Analisis & Pengujian Sistem — Onderdil Motor Indonesia

> Mata Kuliah: Analisis & Pengujian Sistem (IF7A)
> Ketua Kelompok: Muhammad Azfa Eka Satria — 23EO10001

## Anggota Kelompok

- Muhammad Azfa Eka Satria — 23EO10001 (Ketua)
- [Nama Anggota 2] — [NIM]
- [Nama Anggota 3] — [NIM]
- [Nama Anggota 4] — [NIM]
- [Nama Anggota 5] — [NIM]

---

## Deskripsi Proyek (20 poin)

Repositori ini berisi artefak, dokumen, dan kode yang berkaitan dengan tugas mata kuliah Analisis & Pengujian Sistem. Proyek ini bertujuan untuk menganalisis kebutuhan, merancang arsitektur, mengimplementasikan, dan menguji sistem katalog sparepart motor OEM berbasis mobile.

Sistem ini adalah aplikasi mobile Flutter yang terintegrasi dengan backend Supabase untuk mengelola katalog sparepart motor OEM. Fitur utama meliputi: pencarian sparepart (TF-IDF), keranjang belanja cloud (realtime), checkout via RPC transaksi, upload bukti transfer (signed URL), verifikasi pembayaran oleh admin, dan laporan penjualan dengan export CSV.

Tujuan pengujian: membuktikan setiap fungsionalitas utama berjalan sesuai spesifikasi, keamanan data terjaga di 2 lapis (aplikasi + database RLS), dan menghasilkan artefak pengujian yang dapat diulang (unit test, checklist manual, RLS matrix).

---

## Desain Proyek — Unified Modeling System (20 poin)

### Use Case Diagram
File: [`docs/diagram/use-case-diagram.mermaid`](docs/diagram/use-case-diagram.mermaid)

Aktors: Customer, Admin

- **Customer**: Register/Login, Cari Sparepart, Lihat Katalog, Tambah Keranjang, Checkout, Upload Bukti Transfer, Lihat Riwayat Pesanan
- **Admin**: CRUD Sparepart, Kelola Pesanan, Verifikasi/Reject Pembayaran, Laporan Penjualan, Export CSV, Update Stok

### Sequence Diagram
File: [`docs/diagram/sequence-diagram.mermaid`](docs/diagram/sequence-diagram.mermaid)

Alur checkout: Customer → Katalog → Keranjang → Checkout (RPC `checkout_cart`) → Order dibuat, stok berkurang, keranjang kosong → Upload bukti transfer → Admin verifikasi → Status order berubah (realtime).

### Activity Diagram
File: [`docs/diagram/activity-diagram.mermaid`](docs/diagram/activity-diagram.mermaid)

Alur customer: Cari Sparepart → Cek Stok → Tambah Keranjang → Checkout → Upload Bukti → Tunggu Verifikasi → Selesai
Alur admin: Login → CRUD Part / Kelola Pesanan / Laporan

---

## Arsitektur Proyek (20 poin)

### C4 Model

**Level 1 — Context:**
- 2 user (Customer, Admin) → Flutter App → Supabase (Auth, Postgres, Realtime, Storage)

**Level 2 — Container:**
- Flutter App (11 widget/container: Splash, Auth, Katalog, Cart, Checkout, Payment Upload, Order History, Admin Panel, Admin Orders, Sales Report, CartModel, TfIdfSearch)
- Supabase Backend (Auth, Postgres, Realtime, Storage)

**Level 3 — Component (Database):**
- Tabel: `parts`, `profiles`, `cart_items`, `orders`, `order_items`, `shipping_options`
- RPC: `checkout_cart`, `submit_payment_proof`, `get_email_by_username`
- Storage: `part-images`, `payment-proofs`
- Realtime: `supabase_realtime` (cart_items, parts, orders)

**Deployment:**
- Developer → Flutter Build (`--dart-define-from-file`) → Android APK / iOS / Web → Supabase

Lihat detail: [`docs/arsitektur/architecture-design.md`](docs/arsitektur/architecture-design.md)

---

## Tech Stack (20 poin)

| Layer | Teknologi |
|---|---|
| FE | Flutter (Material 3, Dart SDK ^3.13.4) |
| BE | Supabase (Auth, Postgres, Realtime, Storage) |
| Database | PostgreSQL (via Supabase) |
| Service | Supabase (Auth, RLS, RPC, Storage, Realtime) |
| Dependencies | `supabase_flutter` 2.17.2, `image_picker` 1.1.2, `cupertino_icons` 1.0.8 |
| Testing | `flutter_test`, `flutter_lints` 6.0.0 |

---

## Cara Menjalankan

1. Install Flutter SDK & NDK Android
2. Salin template konfigurasi:
   ```bash
   cp config/dev.json.example config/dev.json
   ```
3. Edit `config/dev.json` dengan kredensial Supabase:
   ```json
   {
     "SUPABASE_URL": "https://your-project.supabase.co",
     "SUPABASE_ANON_KEY": "your-anon-key"
   }
   ```
4. Jalankan dengan:
   ```bash
   flutter run --dart-define-from-file=config/dev.json
   ```

---

## Multi-Role

| Role | Hak Akses |
|---|---|
| **Customer** | Cari sparepart (TF-IDF), keranjang belanja cloud, checkout, upload bukti transfer, riwayat pesanan |
| **Admin** | CRUD sparepart, kelola pesanan, verifikasi/tolak pembayaran, laporan penjualan + export CSV, update stok |

Keamanan data diterapkan dengan **Row Level Security (RLS)** di Supabase.

---

## Pengujian

| Jenis | Hasil |
|---|---|
| Unit test | 43/43 lulus (`flutter test`) |
| RLS matrix | 11 PASS, 0 FAIL (customer + admin) |
| Manual checklist | 6/8 customer PASS, 5/6 admin PASS |
| Static analysis | `flutter analyze` — No issues found |

Detail: [`docs/pengujian/rencana-pengujian.md`](docs/pengujian/rencana-pengujian.md) | [`docs/pengujian/bug-tracker.md`](docs/pengujian/bug-tracker.md)

---

## Dokumentasi Lengkap

- [`docs/README.md`](docs/README.md) — index deliverable
- [`docs/arsitektur/architecture-design.md`](docs/arsitektur/architecture-design.md) — C4 architecture
- [`docs/diagram/`](docs/diagram/) — Use Case, Sequence, Activity diagram
- [`docs/pengujian/`](docs/pengujian/) — test plan, bukti, bug tracker
- [`docs/presentasi/progress-presentation.md`](docs/presentasi/progress-presentation.md) — slide progress