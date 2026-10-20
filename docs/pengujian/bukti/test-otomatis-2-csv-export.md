# Buksi Pengujian Otomatis #2 — Export CSV & Omset

> Terkait: `docs/pengujian/rencana-pengujian.md` bagian 6.3
> Tanggal: 14 Oktober 2026

## Perubahan Kode (refactor T3 — testability)

Fungsi private di `SalesReportScreen` diekstrak menjadi fungsi murni
di **`lib/csv_utils.dart`** agar bisa diuji unit test:

| Sebelum (private, tak terjangkau test) | Sesudah (publik, murni) |
|---|---|
| `_csvCell()` | `csvCell()` |
| `_generateCsv()` | `generateSalesCsv(orders)` |
| `_totalRevenue` | `salesRevenue(orders)` |

`SalesReportScreen` kini hanya mendelegasikan — perilaku UI tidak berubah
(dibuktikan `flutter analyze`: *No issues found*).

## Hasil

```
00:02 +43: All tests passed!
```

**16 test CSV — 16 lulus. Total seluruh suite: 43 test, 43 lulus, 0 gagal.**

## Rincian Test Case

### `csvCell` — escaping & proteksi formula (9 test)

| ID | Uji | Input | Output diharapkan | Hasil |
|---|---|---|---|---|
| U-V-01 | Field biasa | `Budi` | `"Budi"` | ✅ |
| U-V-02 | Koma aman | `Budi, S.Pd` | `"Budi, S.Pd"` | ✅ |
| U-V-03 | Kutip ganda | `He said "hi"` | `"He said ""hi"""` | ✅ |
| U-V-04 | Formula `=` | `=1+1` | `"'=1+1"` | ✅ |
| U-V-05 | Formula `+` | `+6281234567` | `"+6281234567"` | ✅ |
| U-V-06 | Formula `-` | `-2+3+cmd` | `"'-2+3+cmd"` | ✅ |
| U-V-07 | Formula `@` | `@SUM(A1)` | `'@SUM(A1)"` | ✅ |
| U-V-08 | Kontrol (tab) | `\tABS` | `"'\tABS"` | ✅ |
| U-V-09 | Kosong | `` | `""` | ✅ |

### `generateSalesCsv` — struktur & format (5 test)

| ID | Uji | Hasil |
|---|---|---|
| U-V-10 | Header persis sesuai spesifikasi | ✅ |
| U-V-11 | Jumlah baris = 1 header + 3 order | ✅ |
| U-V-12 | Tanggal valid terformat lokal (aman lintas timezone) | ✅ |
| U-V-13 | Tanggal tidak valid → kolom tanggal kosong | ✅ |
| U-V-14 | Total 2 desimal (`15000.00`) | ✅ |

### `salesRevenue` — omset (2 test)

| ID | Uji | Hasil |
|---|---|---|
| U-V-15 | **Regresi bug omset lama**: hanya `verified` + bukan `cancelled` | ✅ |
| U-V-16 | Tanpa order → 0 | ✅ |

**Detail U-V-15 (bahan presentasi):** fixture berisi 100.000 (verified+completed),
50.000 (verified+**cancelled**), 75.000 (uploaded+pending) → omset benar
**100.000** — membuktikan pesanan terverifikasi yang dibatalkan tidak lagi
terhitung (bug versi lama memakai "atau").

## Catatan Rekonsiliasi Spesifikasi ↔ Implementasi

Rencana pengujian awalnya menuliskan fallback tanggal invalid = `-` (U-V-13).
Setelah dicek ke kode, implementasi menghasilkan kolom **kosong** (`""`).
Kolom kosong dipilih lebih aman: tanda `-` di awal cell justru memicu
neutralisasi formula sehingga tampil apostrof `'-` di Excel. Spesifikasi di
`rencana-pengujian.md` disesuaikan, test mengikuti keputusan tersebut.

## Perintah untuk Mengulang

```bash
flutter test
```
