# Bug Tracker — OEM Sparepart Catalog

> Format pelaporan: `docs/pengujian/rencana-pengujian.md` bagian 12
> Sumber temuan: unit test, checklist manual, tes RLS

---

## B-001 — Alur "Lihat Detail Produk" tidak ada di implementasi

| Field | Isi |
|---|---|
| **Severity** | Low |
| **Tanggal** | 17 Okt 2026 (checklist manual M-03) |
| **Ditemukan oleh** | Pengujian manual (emulator) |

**Langkah reproduce:**
1. Login sebagai customer → Katalog
2. Coba klik salah satu kartu produk (mis. "Knalpot Racing")

**Expected (spesifikasi):**
`docs/diagram/activity-diagram.mermaid` menampilkan node **"Lihat Detail Produk"** — alur: Katalog → Cari → Lihat Detail → cek stok → tambah keranjang.

**Actual:**
Kartu produk tidak dapat diklik (tidak ada `onTap`/`InkWell` di `PartsCatalogScreen`). Namun **seluruh informasi produk tampil lengkap langsung di kartu** (foto, nama, part number, kategori, harga, stok) sehingga fungsi pengguna tetap terpenuhi.

**Analisis:**
Deviasi spesifikasi ↔ implementasi, **bukan hilangnya fungsi**. Data yang rencananya ditampilkan di halaman detail sudah ditampilkan di katalog.

**Rekomendasi:**
Perbarui `activity-diagram.mermaid`: hapus node "Lihat Detail Produk" dan sambungkan `Cari Sparepart → {Stok > 0?} → Tambah ke Keranjang` (opsi B — disarankan, sesuai implementasi, tanpa menambah kode mendekati deadline).
Alternatif (opsi A): buat halar detail produk — **tidak disarankan** mendekati deadline, manfaat rendah.

**Status:** ✅ Selesai — opsi B (update activity diagram, hapus node "Lihat Detail Produk")

---

## B-002 — Role warehouse dihapus dari sistem

| Field | Isi |
|---|---|
| **Severity** | Low (keputusan desain, bukan bug) |
| **Tanggal** | 17 Okt 2026 |
| **Ditemukan oleh** | Analisis pengujian (diskusi tim) |

**Latar belakang:**
Role `warehouse` awalnya dibuat dengan asumsi warehouse staff perlu akses terpisah untuk update stok. Ternyata:
1. App belum punya UI khusus warehouse
2. Fitur warehouse cuma update stok (bisa dilakukan admin)
3. Tidak ada requirement dari dosen untuk role warehouse

**Keputusan:**
Hapus role `warehouse` dari sistem. Update stok kini dilakukan oleh `admin`.

**Yang sudah dilakukan:**
- Akun `staffgudang` dihapus dari tabel `profiles` (17 Okt 2026)
- RLS policies warehouse diabaikan (tidak dihapus, tidak aktif karena tidak ada role warehouse)
- Trigger DB `"Staff gudang hanya boleh mengubah stok"` dibiarkan (tidak aktif, tidak mengganggu)

**Dampak ke pengujian:**
- Test case warehouse (S-04a, S-04b, S-09a, M-09 s/d M-12) dihapus dari test plan
- RLS matrix disederhanakan: customer + admin saja
- Checklist manual digabung ke admin

**Status:** ✅ Selesai — keputusan desain, bukan bug
