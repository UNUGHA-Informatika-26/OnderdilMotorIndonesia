# Analisis & Pengujian Sistem — Onderdil Motor Indonesia

> Mata Kuliah: Analisis & Pengujian Sistem (IF7A)
> Ketua Kelompok: Muhammad Azfa Eka Satria — 23EO10001

## Anggota Kelompok

- Muhammad Azfa Eka Satria — 23EO10001 (Ketua)
- Wildan Fadhillah — 23EO10002

---

## Deskripsi Proyek (20 poin)

Repositori ini berisi artefak, dokumen, dan kode yang berkaitan dengan tugas mata kuliah Analisis & Pengujian Sistem. Proyek ini bertujuan untuk menganalisis kebutuhan, merancang arsitektur, mengimplementasikan, dan menguji sistem katalog sparepart motor OEM berbasis mobile.

Sistem ini adalah aplikasi mobile Flutter yang terintegrasi dengan backend Supabase untuk mengelola katalog sparepart motor OEM. Fitur utama meliputi: pencarian sparepart (TF-IDF), keranjang belanja cloud (realtime), checkout via RPC transaksi, upload bukti transfer (signed URL), verifikasi pembayaran oleh admin, dan laporan penjualan dengan export CSV.

Tujuan pengujian: membuktikan setiap fungsionalitas utama berjalan sesuai spesifikasi, keamanan data terjaga di 2 lapis (aplikasi + database RLS), dan menghasilkan artefak pengujian yang dapat diulang (unit test, checklist manual, RLS matrix).

---

## Analisis Masalah (Problem-Oriented)

### Masalah Bisnis
1. **Katalog tidak terstruktur** — Customer kesulitan mencari sparepart yang tepat karena katalog masih berupa kertas/PDF tanpa pencarian.
   - *Solusi:* TF-IDF search untuk pencarian berbasis relevansi.
2. **Keranjang tidak persisten** — Customer mengalami cart abandonment akibat kehilangan keranjang saat ganti device atau sesi. Hal ini menghambat konversi penjualan dan merusak pengalaman user yang seamless. Analitik bisnis juga tumpah (tidak bisa melacak cart abandonment rate).
   - *Solusi:* Keranjang berbasis cloud (Supabase). State tersimpan di tabel `cart_items` dengan RLS per-user. Sinkronisasi real-time via Supabase Realtime (WebSocket) memastikan perangkat mana pun menampilkan state terbaru. Optimistic update di Flutter memastikan responsivitas instant. Conflict resolution via timestamp-based merge atau RPC `sync_cart`.
3. **Checkout manual rentan kesalahan** — Proses checkout via chat/telepon menyebabkan kesalahan stok dan pesanan.
   - *Solusi:* Checkout terintegrasi via RPC `checkout_cart` (transaksi atomik).
4. **Tidak ada validasi keamanan data** — Tidak ada pembatasan akses antar role.
   - *Solusi:* RLS (Row Level Security) per-tabel di Supabase.

### Stakeholder Analysis

| Stakeholder | Kebutuhan | Solusi di Sistem |
|---|---|---|
| **Customer** | Cari sparepart dengan mudah, beli online, lacak pesanan | TF-IDF search, cloud cart, checkout, riwayat pesanan |
| **Admin** | Kelola produk, verifikasi pembayaran, laporan penjualan | CRUD sparepart, kelola pesanan, sales report + CSV export |
| **Owner Toko** | Evaluasi bisnis, laporan penjualan | Omset terverifikasi, filter tanggal/status, export CSV |
| **Sistem** | Integritas data, konsistensi stok, keamanan | RPC transaction, RLS, signed URL, stock cap |

### Non-Functional Requirements (NFR)

| ID | Aspek | Target | Implementasi |
|---|---|---|---|
| NFR-01 | Performa search | < 50 ms per query | TF-IDF client-side, O(N) per query |
| NFR-02 | Performa load katalog | Render < 2 detik | FutureBuilder + Supabase REST, pagination via limit |
| NFR-03 | Realtime latency | < 3 detik | Supabase Realtime (WebSocket), live sync cart & orders |
| NFR-04 | Keandalan checkout | Tidak ada partial failure | RPC `checkout_cart` atomic transaction (rollback jika gagal) |
| NFR-05 | Keamanan | Data isolation per-role | RLS per-tabel, signed URL 5 menit, CSV injection protection |
| NFR-06 | Offline | Tidak crash, pesan error jelas | State lokal konsisten, sync menyusul saat koneksi pulih |
| NFR-07 | Scalability | Supabase managed | Connection pooling otomatis, Postgres managed |

### Alternative Scenarios (Exception Handling)

| Skenario | Kondisi | Handling |
|---|---|---|
| **Checkout gagal (stok habis)** | Stok berkurang di tengah checkout | RPC `checkout_cart` rollback seluruh transaksi, customer kembali ke keranjang |
| **Upload bukti gagal** | Network error saat upload | Customer bisa retry upload, bukti lama tetap tersimpan |
| **Admin reject pembayaran** | Bukti tidak valid | Status payment → 'rejected', customer bisa upload ulang |
| **Sesi kedaluwarsa** | Token expired saat aksi | Arahkan ke login, tidak crash |
| **Jaringan putus** | Airplane mode saat buka katalog | Aplikasi tidak crash, pesan error jelas, state lokal konsisten |
| **Order cancelled** | Admin batalkan order | Status → 'cancelled', tidak dihitung dalam omset |

---

## Desain Proyek — Unified Modeling System (20 poin)

### Use Case Diagram
File: [`docs/diagram/images/use-case.png`](docs/diagram/images/use-case.png)

Aktors: Customer, Admin

- **Customer**: Register/Login, Cari Sparepart, Lihat Katalog, Tambah Keranjang, Checkout, Upload Bukti Transfer, Lihat Riwayat Pesanan
- **Admin**: CRUD Sparepart, Kelola Pesanan, Verifikasi/Reject Pembayaran, Laporan Penjualan, Export CSV, Update Stok

### Sequence Diagram
File: [`docs/diagram/images/sequence.png`](docs/diagram/images/sequence.png)

Alur checkout: Customer → Katalog → Keranjang → Checkout (RPC `checkout_cart`) → Order dibuat, stok berkurang, keranjang kosong → Upload bukti transfer → Admin verifikasi → Status order berubah (realtime).

### Activity Diagram
File: [`docs/diagram/images/activity.png`](docs/diagram/images/activity.png)

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

## State Management

### Pola yang Digunakan
- **CartModel** (singleton, `ChangeNotifier`) — state keranjang belanja
- **TfIdfSearch** (class murni, tanpa dependensi) — pencarian sparepart
- **FutureBuilder / StreamBuilder** — untuk data async (orders, parts)

### CartModel (Singleton + ChangeNotifier)
```
CartModel.instance → add() → notifyListeners() → UI rebuild
```
- `add()`: tambah item, cap stok (max 99), skip jika stock = 0
- `decrement()`: qty turun, hapus jika qty = 1
- `clear()` / `clearLocal()`: bersihkan memori
- **Sync DB**: otomatis jika `uid != null` (login), skip jika `uid == null` (test)
- **Optimistic update**: update UI dulu, sync ke DB menyusul

### Mengapa ChangeNotifier (bukan Riverpod/BLoC)?
- Lebih sederhana untuk project skala kecil-menengah
- Tidak perlu dependency tambahan
- Cukup untuk state keranjang yang single-source
- Testable: `Supabase.initialize(url: 'http://localhost', anonKey: 'dummy')` → uid null → sync DB ter-skip

---

## API Documentation (RPC)

### 1. `checkout_cart`
**Deskripsi:** Buat order + order_items, kurangi stok, kosongkan keranjang (atomic transaction).

**Parameter:**
| Param | Tipe | Keterangan |
|---|---|---|
| `p_shipping_name` | text | Nama penerima |
| `p_shipping_phone` | text | No. telepon |
| `p_shipping_address` | text | Alamat pengiriman |
| `p_shipping_option_id` | uuid | ID metode pengiriman |
| `p_items` | jsonb | Array item: `[{part_id, name, part_number, price, quantity}]` |

**Return:** `uuid` (order_id)

**Error:** `insufficient_stock` jika stok tidak cukup

**Langkah internal:**
1. INSERT orders (status=pending, payment_status=pending)
2. INSERT order_items (per item)
3. UPDATE parts SET stock = stock - qty
4. DELETE cart_items WHERE user_id = uid
5. Jika langkah 3 gagal → rollback seluruh transaksi

### 2. `submit_payment_proof`
**Deskripsi:** Update payment_status ke 'uploaded' + simpan path bukti.

**Parameter:**
| Param | Tipe | Keterangan |
|---|---|---|
| `p_order_id` | uuid | ID order |
| `p_proof_path` | text | Path file di bucket payment-proofs |

**Return:** `void`

**Error:** `order_not_found` jika order tidak milik user

### 3. `get_email_by_username`
**Deskripsi:** Resolve username → email untuk login.

**Parameter:**
| Param | Tipe | Keterangan |
|---|---|---|
| `p_username` | text | Username user |

**Return:** `text` (email)

**Error:** `username_not_found` jika tidak ada

---

## Supabase sebagai Backend-as-a-Service (BaaS)

### Mengapa Supabase (bukan Laravel / backend custom)?

Supabase adalah **Backend-as-a-Service (BaaS)** berbasis open-source yang menyediakan seluruh infrastruktur backend dalam satu platform. Untuk project ini, Supabase dipilih karena:

| Kriteria | Supabase (Pilihan Saat Ini) |
|---|---|
| **Kecepatan Pengembangan** | Sangat cepat — Auth, Realtime, Storage built-in |
| **Logika Bisnis** | RPC function (`checkout_cart`) + Service class (`PaymentUploadService`) di client |
| **Realtime** | Bawaan (WebSocket) — live sync cart & orders |
| **Keamanan** | RLS (Row Level Security) di database level |
| **Storage** | Bucket built-in (part-images, payment-proofs) |
| **Autentikasi** | Supabase Auth (email/password, username via metadata) |

### Komponen Supabase yang Digunakan

| Komponen | Fungsi di Project | Contoh Penggunaan |
|---|---|---|
| **Auth** | Login/register, session management, username→email resolve | `get_email_by_username` RPC |
| **Postgres** | Database relasional: `parts`, `profiles`, `cart_items`, `orders`, `order_items`, `shipping_options` | CRUD sparepart, checkout, laporan |
| **RLS** | Keamanan per-row: customer hanya lihat data miliknya, admin full CRUD | Policy `Only full admin can insert parts` |
| **Realtime** | Live sync keranjang & status pesanan antar device | `supabase_realtime` channel (cart_items, parts, orders) |
| **Storage** | Upload & signed URL: foto produk & bukti transfer | Bucket `part-images`, `payment-proofs` (private, signed URL 5 menit) |
| **RPC** | Logika bisnis atomik di server (transaction) | `checkout_cart` (INSERT order + order_items, UPDATE stock, DELETE cart), `submit_payment_proof` |

### Argumen Feasibility

1. **Logika bisnis tidak di client Flutter** — RPC `checkout_cart` dijalankan di server database (PostgreSQL), atomic: INSERT order → INSERT order_items → UPDATE stock → DELETE cart_items. Jika satu gagal, seluruh transaksi rollback.
2. **Service-oriented pattern** — `PaymentUploadService` menangani upload bukti transfer dan generate signed URL. Storage provider bisa diganti (AWS S3, Laravel Storage) tanpa mengubah logika bisnis utama.
3. **Keamanan di database level** — RLS menjamin data isolation per-role, bukan hanya di UI. Customer tidak bisa baca/tulis data orang lain meskipun API dipanggil langsung.
4. **Realtime built-in** — WebSocket native dari Supabase, tidak perlu setup Pusher/Laravel Reverb. Live sync cart antar device < 3 detik.
5. **Hybrid approach (jika dosen tidak setuju)** — Bisa gunakan PostgreSQL (Supabase DB) + Laravel API (framework). Database tetap sama, logika routing/auth middleware diatur Laravel. Ini jalan tengah yang menggabungkan kecepatan Flutter dengan fleksibilitas Laravel.

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