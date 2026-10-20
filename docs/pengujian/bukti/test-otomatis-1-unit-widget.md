# Bukti Pengujian Otomatis #1 — Unit & Widget Test

> Terkait: `docs/pengujian/rencana-pengujian.md` bagian 6 & 7
> Tanggal: 14 Oktober 2026

## Lingkungan Pengujian

| Komponen | Versi |
|---|---|
| Flutter | 3.47.5 (stable) |
| Dart | 3.13.4 |
| OS | Windows 11 Pro 64-bit |
| Perintah | `flutter test --reporter expanded` |

## Hasil

```
00:00 +27: All tests passed!
```

**27 test — 27 lulus, 0 gagal, 0 error.**

## Rincian Test Case

### Unit — Pencarian TF-IDF (`test/search_helper_test.dart`) — 12 test

| ID | Uji | Hasil |
|---|---|---|
| U-S-01 | Query kosong → semua part, urutan asli | ✅ |
| U-S-02 | Query spasi saja dianggap kosong | ✅ |
| U-S-03 | Case-insensitive (`KNALPOT`) | ✅ |
| U-S-04 | Tokenisasi tanda baca (`KP-01`) | ✅ |
| U-S-05 | Term langka unggul (TF-IDF idf weighting) | ✅ |
| U-S-06a | Fallback substring potongan kata (`stan`) | ✅ |
| U-S-06b | Exact match > fallback substring | ✅ |
| U-S-07 | Tidak ada kecocokan → list kosong | ✅ |
| U-S-08 | Field `null` tidak menyebabkan error | ✅ |
| U-S-09 | Daftar part kosong aman | ✅ |
| U-S-10 | Deterministik (query sama → hasil sama) | ✅ |
| U-S-11 | Token berulang tidak mengubah hasil | ✅ |

### Unit — Keranjang (`test/cart_model_test.dart`) — 14 test

| ID | Uji | Hasil |
|---|---|---|
| U-C-01 | Subtotal = price × quantity | ✅ |
| U-C-02 | Item baru masuk quantity 1 | ✅ |
| U-C-03 | Stok 0 tidak bisa ditambahkan | ✅ |
| U-C-04 | Part sama → quantity naik | ✅ |
| U-C-05 | Quantity dibatasi stok | ✅ |
| U-C-06 | Quantity dibatasi 99 (stok 500) | ✅ |
| U-C-07 | Increment di batas tidak menambah | ✅ |
| U-C-08 | Decrement > 1 menurunkan quantity | ✅ |
| U-C-09 | Decrement di 1 menghapus item | ✅ |
| U-C-10 | Remove menghapus item terpilih | ✅ |
| U-C-11 | Clear mengosongkan keranjang | ✅ |
| U-C-13 | TotalPrice menjumlahkan semua subtotal | ✅ |
| U-C-14 | notifyListeners terpanggil tiap mutasi | ✅ |
| U-C-15 | Load tanpa login aman (tidak crash) | ✅ |

### Widget — Splash Screen (`test/widget_test.dart`) — 1 test

| ID | Uji | Hasil |
|---|---|---|
| W-03 | Splash tampil 2 detik → navigasi otomatis | ✅ |

> Catatan: mengganti template bawaan Flutter (counter test) yang tidak
> relevan dengan aplikasi ini.

## Catatan Teknis (bahan laporan)

1. **Metode isolasi tanpa jaringan:** `CartModel` diinisialisasi terhadap
   Supabase dummy (`url` palsu, `currentUser == null`) sehingga seluruh cabang
   sinkronisasi DB ter-skip dan logika lokal keranjang diuji secara murni —
   sesuai strategi di `rencana-pengujian.md` bagian 5 (temuan T2).
2. **Kebersihan kode:** `flutter analyze` tidak menemukan error; hanya tersisa
   3 temuan level *info* yang sudah ada sebelumnya di kode produksi
   (`deprecated_member_use` di `main.dart`/`cart_screen.dart`, `unnecessary_underscores`)
   — tidak memengaruhi fungsi.
3. **Cakupan:** 27 dari ±90 test case rencana pengujian.
   Sisa: CSV export (butuh refactor kecil T3), integration test, RLS test.

## Perintah untuk Mengulang

```bash
flutter test
```
