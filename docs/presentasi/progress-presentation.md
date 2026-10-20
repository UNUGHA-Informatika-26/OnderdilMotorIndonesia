# Progress Presentation — Analisis dan Pengujian Sistem
## Onderdil Motor Indonesia — Kelompok Azfa & Friends

---

## Slide 1: Opening

- Judul: **Analisis dan Pengujian Sistem — Katalog Sparepart Motor OEM**
- Kelompok: Azfa & Friends (maks. 5 orang)
- Project: `oem_sparepart_catalog` — Flutter + Supabase

---

## Slide 2: Problem & Tujuan

**Masalah:**
- Katalog sparepart motor OEM masih berupa kertas / PDF.
- Tidak ada sistem pembelian online, keranjang, atau laporan penjualan real-time.

**Tujuan:**
- Aplikasi mobile Flutter 2-role (customer / admin).
- Backend Supabase dengan RLS, realtime, & storage.

---

## Slide 3: Architecture Design (C4)

**Level 1 — Context:** 2 user (customer, admin) → Flutter App → Supabase (Auth, Postgres, Realtime, Storage).

**Level 2 — Container:** 10 Flutter widget/container + Supabase backend (tables, RPCs, storage buckets).

**Level 3 — Component:** Detail table `parts`, `profiles`, `cart_items`, `orders`, `order_items`, `shipping_options` + RPC `checkout_cart`, `submit_payment_proof`, `get_email_by_username`.

**RLS Matrix:** customer CRUD own cart & orders; admin full CRUD + update stock + verify payment.

Lihat: [`docs/arsitektur/architecture-design.md`](../arsitektur/architecture-design.md)

---

## Slide 4: Diagram

| Jenis | Berkas |
|---|---|
| Use Case | [`docs/diagram/use-case-diagram.mermaid`](../diagram/use-case-diagram.mermaid) |
| Sequence (checkout) | [`docs/diagram/sequence-diagram.mermaid`](../diagram/sequence-diagram.mermaid) |
| Activity (customer/admin) | [`docs/diagram/activity-diagram.mermaid`](../diagram/activity-diagram.mermaid) |

---

## Slide 5: Pembagian Tugas

| No | Nama | Peran | Status |
|---|---|---|---|
| 1 | Azfa (Ketua) | Auth, routing, Supabase, security | ✅ |
| 2 | [Nama] | Analisis & dokumentasi | 🔄 |
| 3 | [Nama] | Customer flow review | ✅ |
| 4 | [Nama] | Admin review | ✅ |
| 5 | [Nama] | Pengujian & non-fungsional | 🔄 |

Lihat: [`docs/pembagian-tugas.md`](../pembagian-tugas.md)

---

## Slide 6: Progress Demo

**Sudah jadi:**
- ✅ Full auth flow (login/register, username/email)
- ✅ Role-based routing (customer / admin)
- ✅ Catalog + TF-IDF search
- ✅ Cloud cart (persist, realtime, stock cap)
- ✅ Checkout via RPC transaction
- ✅ Payment proof upload (signed URL)
- ✅ Admin: CRUD sparepart + image upload
- ✅ Admin: kelola pesanan, verify/reject, update stok
- ✅ Sales report + CSV export (formula injection safe)
- ✅ Security: RLS, gitignore credentials, removed hardcoded defaults

**Pengujian (sudah dilakukan):**
- ✅ Unit test: 43/43 lulus (`flutter test`)
- ✅ RLS matrix: 11 PASS, 0 FAIL (customer + admin)
- ✅ Manual checklist customer: 6/8 PASS (1 SEBAGIAN — B-001)
- ✅ Manual checklist admin: 5/6 PASS (1 SEBAGIAN — M-12 realtime)
- ✅ Static analysis: `flutter analyze` — No issues found

**Next:**
- 🔄 Fix M-12: realtime update saat admin verifikasi pesanan
- 🔄 Update B-001: activity diagram (opsi B)
- 🔄 Demo akhir & Q&A

---

## Slide 7: Q&A

Terima kasih.