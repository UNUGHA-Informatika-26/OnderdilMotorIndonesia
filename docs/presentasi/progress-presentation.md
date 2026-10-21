# Progress Presentation — Analisis dan Pengujian Sistem
## Onderdil Motor Indonesia — Kelompok 99

---

## Slide 1: Opening

**Judul:** Analisis dan Pengujian Sistem — Katalog Sparepart Motor OEM

**Kelompok:** M Azfa Eka Satria (23EO10001) & Wildan Fadhillah (23EO10002)

**Project:** `oem_sparepart_catalog` — Flutter + Supabase

**Mata Kuliah:** Analisis & Pengujian Sistem (IF7A) & Mobile Programming

**Ringkasan:** Aplikasi mobile katalog sparepart motor OEM dengan sistem pembelian online, keranjang realtime, verifikasi pembayaran, dan laporan penjualan — dibangun dengan Flutter dan Supabase, diuji dengan unit test, RLS matrix, dan checklist manual.

---

## Slide 2: Problem & Tujuan

**Masalah:**
- Katalog sparepart motor OEM masih berupa kertas / PDF, tidak digital
- Tidak ada sistem pembelian online, keranjang belanja, atau laporan penjualan real-time
- Tidak ada validasi keamanan data antar role (customer vs admin)
- Tidak ada pengujian sistematis untuk memastikan kualitas

**Tujuan:**
- Aplikasi mobile Flutter 2-role (customer / admin) yang bisa diakses via smartphone
- Backend Supabase dengan RLS (Row Level Security), realtime sync, & storage
- Sistem pengujian komprehensif: unit test, widget test, integration test, RLS matrix
- Artefak pengujian yang repeatable dan terdokumentasi

---

## Slide 3: Architecture Design (C4)

**Level 1 — Context:**
Customer → Flutter App → Supabase (Auth, Postgres, Realtime, Storage) → Bank (info rekening)

**Level 2 — Container:**
- 11 Flutter widget/container: Splash, Auth, Katalog, Cart, Checkout, Payment Upload, Order History, Admin Panel, Admin Orders, Sales Report, CartModel, TfIdfSearch
- Supabase Backend: Auth (login/register), Postgres (database relasional), Realtime (live sync), Storage (foto produk & bukti transfer)

**Level 3 — Component (Database):**
- Tabel: `parts` (katalog), `profiles` (user), `cart_items` (keranjang), `orders` (pesanan), `order_items` (item pesanan), `shipping_options` (kurir)
- RPC: `checkout_cart` (transaksi atomik), `submit_payment_proof`, `get_email_by_username`
- Storage: `part-images` (foto produk), `payment-proofs` (bukti transfer)
- Realtime: `supabase_realtime` (cart_items, parts, orders)

**RLS Matrix:** customer CRUD own cart & orders; admin full CRUD + update stock + verify payment.

*Lihat detail: docs/arsitektur/architecture-design.md*

---

## Slide 3b: Mengapa Supabase (bukan Laravel)?

### Argumen Feasibility (untuk meredam kekhawatiran dosen):

1. **Logika bisnis di server (RPC checkout_cart)** — bukan sekadar INSERT dari client. RPC menjalankan INSERT orders → INSERT order_items → UPDATE stock → DELETE cart dalam satu transaksi atomik. Jika satu gagal, seluruh transaksi rollback. Ini setara dengan Controller/Service di Laravel.

2. **Service-oriented pattern (PaymentUploadService)** — khusus menangani upload bukti + generate signed URL. Storage provider bisa diganti (AWS S3, Laravel Storage) tanpa ubah logika bisnis utama. Prinsip Separation of Concerns.

3. **Keamanan di database level (RLS)** — Row Level Security menjamin data isolation per-role langsung di Postgres, bukan hanya middleware di aplikasi. Customer tidak bisa baca data orang lain meskipun API dipanggil langsung.

4. **Realtime built-in** — WebSocket native, live sync cart & orders < 3 detik. Tidak perlu setup Pusher/Laravel Reverb.

5. **Hybrid approach (jika dosen tidak setuju)** — Bisa gunakan PostgreSQL (Supabase DB) + Laravel API. Database tetap sama, logika routing/auth middleware diatur Laravel. Jalan tengah yang menggabungkan kecepatan Flutter dengan fleksibilitas Laravel.

### Tabel Perbandingan:

| Kriteria | Supabase |
|---|---|
| Kecepatan dev | Sangat cepat (Auth, Realtime, Storage built-in) |
| Logika bisnis | RPC database / Service class |
| Realtime | Bawaan (WebSocket, live sync < 3 detik) |
| Keamanan | RLS di database level |
| Storage | Bucket built-in (part-images, payment-proofs) |
| Autentikasi | Supabase Auth (email/password, username) |

### Bukti dari Diagram:
- **Sequence Diagram** → `checkout_cart` (RPC) + `PaymentUploadService` (service layer)
- **Use Case Diagram** → Verifikasi pembayaran, CRUD, RLS per-role
- **Activity Diagram** → Alur admin & customer terpisah

---

## Slide 4: Diagram

| Jenis | Berkas | Keterangan |
|---|---|---|
| Use Case | docs/diagram/use-case-diagram.md | Aktor: Customer, Admin. 14 use case. |
| Sequence (checkout) | docs/diagram/sequence-diagram.md | Alur checkout: cart → RPC → order → upload bukti → verifikasi |
| Activity (customer/admin) | docs/diagram/activity-diagram.md | Alur customer: cari → keranjang → checkout → bayar. Alur admin: CRUD → kelola pesanan → laporan |

---

## Slide 5: Pembagian Tugas

| No | Nama | Peran | Status |
|---|---|---|---|
| 1 | Muhammad Azfa Eka Satria (Ketua) | Auth, routing, Supabase, security, Admin review | Selesai |
| 2 | Wildan Fadhillah | Analisis & dokumentasi, Customer flow review | Selesai |

---

## Slide 6: Progress Demo

**Fitur yang sudah jadi:**
- Full auth flow (login/register, username/email)
- Role-based routing (customer / admin)
- Catalog + TF-IDF search (pencarian sparepart berbasis relevansi)
- Cloud cart (persist di DB, realtime sync, stock cap)
- Checkout via RPC transaction (stok berkurang atomik)
- Payment proof upload (signed URL, expired 5 menit)
- Admin: CRUD sparepart + image upload (part-images bucket)
- Admin: kelola pesanan, verify/reject pembayaran, update stok
- Sales report + CSV export (formula injection safe — neutralisasi =, +, -, @, tab, CR)
- Security: RLS, gitignore credentials, removed hardcoded defaults

**Pengujian (sudah dilakukan):**
- Unit test: 43/43 lulus (flutter test) — TF-IDF 11, CartModel 15, CSV 16
- RLS matrix: 11 PASS, 0 FAIL (customer + admin, 2-role)
- Manual checklist customer: 6/8 PASS (1 SEBAGIAN — B-001)
- Manual checklist admin: 5/6 PASS (1 SEBAGIAN — M-12 realtime)
- Static analysis: flutter analyze — No issues found

**Bug yang ditemukan & ditangani:**
- B-001 (Low): "Lihat Detail Produk" tidak ada di implementasi → opsi B (update diagram)
- B-002 (Low): Role warehouse dihapus (sederhanakan ke admin)
- B-003 (High): Manipulasi status order → integritas omset → fix UI + database trigger

---

## Slide 7: Testing Strategy

**Test Pyramid (dari bawah ke atas):**

```
        ┌────────────────┐
        │  Manual/E2E    │  ← Checklist demo (M-01 s/d M-14)
        ├────────────────┤
        │  Integration   │  ← Supabase, RLS matrix
        ├────────────────┤
        │  Widget Test   │  ← Perilaku UI per screen
        ├────────────────┤
        │  Unit Test     │  ← Logika murni (mayoritas test case)
        └────────────────┘
```

**Strategi:**
- Sebisa mungkin test otomatis di lapisan paling bawah (cepat, stabil)
- Integrasi hanya untuk jalur yang benar-benar menyentuh Supabase
- RLS matrix: uji via REST API (curl/PowerShell) dengan 2 role token
- Testability: refactor T2 (CartModel client optional) & T3 (ekstraksi csv_utils.dart)

**Exit criteria:**
- Unit test ≥ 90% | Widget test ≥ 80% | Integration & RLS 100% kritis
- Bug Critical/High: 0 terbuka | Checklist manual: semua pass atau ada catatan

---

## Slide 8: Rencana Pengujian (Ringkasan)

| Bagian | Isi |
|---|---|
| Unit Test | TF-IDF search (11 kasus), CartModel (15 kasus), CSV export & omset (16 kasus) |
| Widget Test | Auth, katalog, cart, checkout, payment, admin, laporan (17 kasus) |
| Integration | Register→login, checkout E2E, upload bukti, verifikasi admin, CRUD, realtime |
| RLS Matrix | S-01 s/d S-25 (parts, cart, orders, profiles, RPC) |
| Non-Fungsional | Performa search, load katalog, realtime latency, offline, accessibility |
| Manual Checklist | 14 skenario (customer 8, admin 6) |

Detail: docs/pengujian/rencana-pengujian.md

---

## Slide 9: Bug Tracker

| ID | Severity | Judul | Status |
|---|---|---|---|
| B-001 | Low | Alur "Lihat Detail Produk" tidak ada di implementasi | Selesai (update diagram) |
| B-002 | Low | Role warehouse dihapus dari sistem | Selesai (keputusan desain) |
| B-003 | High | Manipulasi status order → integritas omset | Fixed (UI + database trigger) |

**B-003 detail:** Admin bisa ubah status order (pending/completed/cancelled) tanpa validasi payment_status. Fix: UI disable tombol sesuai state + database trigger validasi transisi.

Detail: docs/pengujian/bug-tracker.md

---

## Slide 10: Q&A

Terima kasih.