# Pembagian Tugas Per Individu

Kelompok maksimal 5 orang. Di bawah adalah pembagian berdasarkan fungsionalitas yang sudah diimplementasikan di repo. Anggota yang bertanda `(Ketua)` adalah ketua kelompok.

---

## 1. Muhammad Azfa Eka Satria — **Ketua Kelompok** (23EO10001)

**Tugas:**
- [x] Maintain & review `lib/main.dart` (routing, auth gate, role router)
- [x] Kelola Supabase project (auth, RLS, storage buckets, RPC)
- [x] Koordinasi progress & merge kontribusi anggota
- [x] Finalisasi architecture design & penulisan laporan

**Done:** Auth flow (login/register), role-based routing, Supabase config, security hardening (anon key removal).

---

## 2. [Nama Anggota 2] — **Analisis & Dokumentasi**

**Tugas:**
- [ ] Analisis kebutuhan fungsional (use case, user story)
- [ ] Dokumentasi `design.md` & `figma_make_prompt.md`
- [ ] Tulis `docs/README.md` (index deliverable)
- [ ] Siapkan pertanyaan pengujian (test case checklist)

**Status:** Dilakukan — desain spec & Figma prompt sudah ada di repo.

---

## 3. [Nama Anggota 3] — **Customer Flow (Frontend)**

**Tugas:**
- [ ] Review `lib/main.dart` PartsCatalogScreen (katalog, search TF-IDF)
- [ ] Review `lib/cart_screen.dart` (keranjang, checkout, shipping)
- [ ] Review `lib/order_history_screen.dart` (riwayat pesanan)
- [ ] Review `lib/payment_upload_screen.dart` (upload bukti transfer)
- [ ] Buat sequence diagram alur customer

**Done:** Semua screen customer sudah di-review.

---

## 4. [Nama Anggota 4] — **Admin & Warehouse Flow (Frontend + RLS)**

**Tugas:**
- [ ] Review `lib/admin_page.dart` (CRUD sparepart, form, image upload)
- [ ] Review `lib/admin_orders_screen.dart` (kelola pesanan, verifikasi)
- [ ] Review `lib/sales_report_screen.dart` (laporan, CSV export)
- [ ] Analisis RLS policy di `supabase_phase2_migration.sql`
- [ ] Buat activity diagram alur admin/staff

**Done:** Semua screen admin/staff sudah di-review.

---

## 5. [Nama Anggota 5] — **Pengujian & Non-Fungsional**

**Tugas:**
- [ ] Buat rencana pengujian (unit, widget, integration)
- [ ] Analisis keamanan (RLS, signed URL, CSV injection)
- [ ] Analisis performa & scalability (realtime stream, storage)
- [ ] Siapkan pertanyaan demo untuk presentasi

**Status:** Dilakukan — security review (anon key), CSV formula injection protection, realtime streams.

---

## Ringkasan Progress

| Anggota | Fitur | Status |
|---|---|---|
| Azfa (Ketua) | Auth, routing, Supabase, security | ✅ Selesai |
| Anggota 2 | Analisis & dokumentasi | ✅ Sebagian (desain spec ada) |
| Anggota 3 | Customer flow review | ✅ Selesai |
| Anggota 4 | Admin/Warehouse review | ✅ Selesai |
| Anggota 5 | Pengujian & non-fungsional | 🔄 Dalam progress |

**Next:** Presentasi & demo progress.