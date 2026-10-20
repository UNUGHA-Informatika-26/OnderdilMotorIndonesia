# Bukti Pengujian Manual #1 — Checklist Customer (M-01 s/d M-08)

> Terkait: `docs/pengujian/rencana-pengujian.md` bagian 11
> Tanggal: 17 Oktober 2026
> Pelaksanaan: manual di emulator Pixel 7 (Android 16 / API 36), akun customer

## Hasil

| ID | Skenario | Hasil | Catatan |
|---|---|---|---|
| M-01 | Login akun customer | ✅ PASS | Login sukses, masuk katalog |
| M-02 | Cari produk ("knalpot") | ✅ PASS | Hasil pencarian ketemu & terurut relevansi |
| M-03 | Detail produk | ⚠️ SEBAGIAN | Tidak ada layar detail — kartu tidak dapat diklik, tapi seluruh info (foto, nama, PN, harga, stok) tampil lengkap langsung di kartu katalog. Tercatat sebagai **B-001** |
| M-04 | Tambah keranjang (3×) | ✅ PASS | Badge keranjang naik sesuai jumlah |
| M-05 | Keranjang + isi alamat & pilih kurir | ✅ PASS | Form terisi, total terhitung |
| M-06 | Checkout | ✅ PASS | Pesanan dibuat (pending) **dan stok berkurang** — bukti RPC `checkout_cart` berjalan sebagai transaksi |
| M-07 | Upload bukti transfer | ⏸️ TERTUNDA → ✅ *lanjut* | Tertahan karena galeri emulator kosong (**kendala environment, bukan defect aplikasi**). Solusi: 2 gambar tes (`bukti-transfer-test.png`, `bukti-transfer-test2.png`) di-push via adb ke `/sdcard/Pictures/` dan terindeks MediaStore — silakan ulangi M-07 |
| M-08 | Riwayat pesanan | ✅ PASS | Order muncul dengan status sesuai |

## Ringkasan

- **6 PASS** — **1 SEBAGIAN** (B-001) — **1 tertunda, teratasi** (environment emulator)
- Temuan defect: **B-001** (lihat `docs/pengujian/bug-tracker.md`)
- Keluhan "gallery kosong" bukan defect aplikasi; pencatatannya di sini sebagai **kendala lingkungan pengujian** + solusi yang diterapkan (adb push + MediaStore scan).

## Lanjutan

Checklist admin/warehouse (M-09 s/d M-16) menunggu setelah tes RLS & pengisian bukti M-07.
