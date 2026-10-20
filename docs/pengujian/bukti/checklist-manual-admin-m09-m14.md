# Checklist Manual Admin — M-09 s/d M-14

> Tanggal: 17 Okt 2026
> Tester: Anggota 5 (Pengujian & Non-Fungsional)
> Akun: `azfasatriza@gmail.com` (admin)

---

## M-09: Login admin
- [x] Login dengan akun admin
- **Hasil:** PASS
- **Bukti:** Panel admin tampil (CRUD part, kelola pesanan, laporan)

## M-10: Update stok
- [x] Pilih part → ubah stok
- **Hasil:** PASS
- **Catatan:** Stok berubah dan tersimpan

## M-11: CRUD part
- [x] Tambah part + foto → edit → hapus
- **Hasil:** PASS
- **Catatan:** Konsisten di katalog

## M-12: Verifikasi pembayaran / realtime pesanan
- [x] Buka "Kelola Pesanan"
- [x] Verifikasi order
- [x] Reject order
- **Hasil:** SEBAGIAN
- **Catatan:** Status order berubah di database, tapi UI customer tidak auto-refresh saat admin verifikasi. Perlu tambahan realtime listener di halaman riwayat order customer.
- **Status:** 🔄 Perlu fix atau dicatat sebagai known limitation

## M-13: Laporan
- [x] Buka menu "Laporan"
- [x] Filter tanggal & status
- **Hasil:** PASS
- **Catatan:** Omset muncul = Rp 15.032,00 (hanya order verified)

## M-14: Export CSV
- [x] Klik export/copy CSV
- [x] Paste ke Excel/Notepad
- **Hasil:** PASS
- **Catatan:** Kolom rapi, formula injection safe (`'-` di awal cell)

---

## Ringkasan

| ID | Hasil |
|---|---|
| M-09 | ✅ PASS |
| M-10 | ✅ PASS |
| M-11 | ✅ PASS |
| M-12 | ⚠️ SEBAGIAN (realtime) |
| M-13 | ✅ PASS |
| M-14 | ✅ PASS |

**Total:** 5 PASS, 1 SEBAGIAN
