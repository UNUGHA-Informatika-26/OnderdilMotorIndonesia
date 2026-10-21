# Rencana Pengujian — Onderdil Motor Indonesia

> Project: `oem_sparepart_catalog` (Flutter + Supabase)
> Kelompok: Azfa & Friends — Mata Kuliah: Analisis dan Pengujian Sistem
> Penanggung jawab: Anggota 5 (Pengujian & Non-Fungsional)

---

## 1. Tujuan

1. Membuktikan setiap fungsionalitas utama (auth, katalog, keranjang, checkout, pembayaran, admin, laporan) berjalan sesuai spesifikasi.
2. Membuktikan keamanan data terjaga di **2 lapis**: aplikasi (UI) dan database (RLS).
3. Menghasilkan artefak pengujian yang dapat diulang (repeatable): test otomatis + checklist manual untuk demo.

**Exit criteria (kriteria selesai):**

| Kriteria | Target |
|---|---|
| Unit test lulus | ≥ 90% test case pada bagian 6 |
| Widget test lulus | ≥ 80% test case pada bagian 7 |
| Integration & RLS test lulus | 100% test case kritis (bagian 8–9, severity Critical/High) |
| Bug Critical/High | 0 terbuka |
| Checklist manual (bagian 11) | Semua pass atau ada catatan defek |

---

## 2. Ruang Lingkup

**In scope:**

- Logika murni (unit): `TfIdfSearch` (`search_helper.dart`), `CartModel`/`CartItem` (`cart_helper.dart`), CSV export & omset (`sales_report_screen.dart`), routing role (`main.dart`).
- Widget: auth page, katalog, keranjang, checkout, upload bukti, riwayat, admin panel, kelola pesanan, laporan.
- Integrasi: alur end-to-end ke Supabase (auth → cart → `checkout_cart` → `submit_payment_proof` → verifikasi admin).
- Keamanan: RLS matrix, signed URL bukti transfer, CSV formula injection, penyimpanan kredensial.
- Non-fungsional: performa search, realtime stream, perilaku offline/gangguan jaringan.

**Out of scope:**

- Pembayaran otomatis (payment gateway) — sistem memakai transfer manual + upload bukti.
- Load testing besar-besaran (≥ 1000 user simultan) — cukup pengujian responsivitas di device nyata.
- Uji coba di web/desktop build (fokus Android/iOS mobile).

---

## 3. Strategi Pengujian (Test Pyramid)

```
        ┌────────────────┐
        │  Manual/E2E    │  ← Checklist demo (bagian 11)
        ├────────────────┤
        │  Integration   │  ← Supabase lokal/staging, RLS matrix
        ├────────────────┤
        │  Widget Test   │  ← Perilaku UI per screen
        ├────────────────┤
        │  Unit Test     │  ← Logika murni (mayoritas test case)
        └────────────────┘
```

Prinsip: sebisa mungkin test otomatis di lapisan paling bawah (cepat, stabil), integrasi hanya untuk jalur yang benar-benar menyentuh Supabase.

---

## 4. Environment & Tools

| Kebutuhan | Alat | Keterangan |
|---|---|---|
| Unit & widget test | `flutter_test` (sudah ada) | `flutter test` |
| Mocking | `mocktail` (perlu ditambahkan ke `dev_dependencies`) | Mock `SupabaseClient` |
| Integration test | `integration_test` (SDK Flutter, perlu ditambah) | `flutter test integration_test` |
| Backend lokal | Supabase CLI (`supabase start`) | Postgres + Auth + Storage + Realtime lokal; alternatif: project staging |
| Migrasi & seed | `supabase_phase2_migration.sql` + seed parts/orders | Deterministik untuk repeatable test |
| Static analysis | `flutter analyze` | Preflight sebelum run test |
| Device nyata/emulator | Android emulator / device fisik | Manual test & performa |

**Dependency tambahan yang diusulkan:**

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mocktail: ^1.0.4
```

**Pembagian environment:**

- `local` (Supabase CLI) → unit/integration otomatis, data seed deterministik.
- `staging` → demo presentasi, data manusiawi (bukti transfer asli, beberapa order).
- Kredensial test **tidak pernah** di-commit: pakai `--dart-define-from-file=config/dev.json` (mengikuti pola yang sudah dipakai project).

---

## 5. Testability Assessment (temuan & rekomendasi)

Analisis kode menemukan beberapa hambatan testability. Ini bagian penting dari "analisis" — dokumentasikan sebagai temuan:

| # | Temuan | Dampak ke pengujian | Rekomendasi |
|---|---|---|---|
| T1 | `TfIdfSearch` adalah class Dart murni tanpa dependensi | ✅ Langsung bisa diuji unit | Tidak perlu ubahan |
| T2 | `CartModel` singleton, memanggil `Supabase.instance.client` langsung | Sulit di-mock | Kecil: tambah optional param `SupabaseClient? client` di konstruktor + `@visibleForTesting`. **Alternatif tanpa refactor:** di test inisialisasi `Supabase.initialize(url: 'http://localhost', anonKey: 'test')` — karena `currentUser == null`, semua cabang sync DB otomatis ter-skip, logika lokal (add/increment/decrement/clear) tetap bisa diuji |
| T3 | `_csvCell()` & `_totalRevenue` private di dalam `State` | Tidak bisa dipanggil dari test | Ekstrak ke `lib/csv_utils.dart` sebagai fungsi publik ber-`@visibleForTesting` |
| T4 | `test/widget_test.dart` masih bawaan Flutter (counter smoke test) | Tidak relevan, false confidence | Hapus/ganti dengan test aplikasi nyata |
| T5 | RPC (`checkout_cart`, `submit_payment_proof`) hanya ada di database | Tak terjangkau unit test | Uji lewat integration test / pgTAP di SQL |

> Estimasi effort refactor T2 + T3: < 1 jam, tidak mengubah perilaku produksi.

---

## 6. Rencana Unit Test

File: `test/search_helper_test.dart`, `test/cart_model_test.dart`, `test/csv_utils_test.dart`

### 6.1 `TfIdfSearch` (search_helper.dart)

Fixture: 3 part — `{"name":"Knalpot Racing","part_number":"KP-01","category":"Exhaust"}`, `{"name":"Knalpot Standard","part_number":"KS-02","category":"Exhaust"}`, `{"name":"Filter Oli","part_number":"FO-03","category":"Engine"}`.

| ID | Kasus | Input | Expected result |
|---|---|---|---|
| U-S-01 | Query kosong mengembalikan semua data | `search("")` | List asli (3 item, urutan sama) |
| U-S-02 | Query whitespace-only dianggap kosong | `search("   ")` | List asli (3 item) |
| U-S-03 | Tokenisasi case-insensitive | `search("KNALPOT")` | 2 hasil (kedua knalpot) |
| U-S-04 | Pemisah tanda baca | `search("KP-01")` | 1 hasil, part KP-01 (di-token jadi `kp`,`01`) |
| U-S-05 | Relevansi: term langka di atas term umum | `search("oli")` | Filter Oli di posisi 1 (idf `oli` > idf `knalpot`) |
| U-S-06 | Fallback substring untuk potongan kata | `search("racing knalpot sport")` | "Knalpot Racing" tetap muncul (skor fallback 0.01), urutan hasil exact match tetap di atas |
| U-S-07 | Tidak ada kecocokan → list kosong | `search("bodykit ninja")` | `[]` |
| U-S-08 | Part dengan field null tidak crash | Part `{"name":null,"part_number":"X","category":null}` + `search("x")` | 1 hasil, tidak throw |
| U-S-09 | Daftar part kosong | `TfIdfSearch([]).search("apa")` | `[]` |
| U-S-10 | Query berulang sama → hasil sama (deterministik) | `search("knalpot")` 2× | Urutan identik |
| U-S-11 | Token berulang di query tidak error | `search("knalpot knalpot")` | Sama dengan hasil `search("knalpot")` |

### 6.2 `CartModel` / `CartItem` (cart_helper.dart)

Setup: inisialisasi Supabase dengan URL dummy (lihat T2) agar `uid == null` → sync DB ter-skip; uji state lokal murni.

| ID | Kasus | Langkah | Expected result |
|---|---|---|---|
| U-C-01 | Subtotal benar | `CartItem(price: 15000, quantity: 3).subtotal` | `45000.0` |
| U-C-02 | Tambah item baru (stock > 0) | `add(stock: 5)` | Qty = 1, `totalCount` = 1 |
| U-C-03 | Tambah item stock 0 ditolak | `add(stock: 0)` | Keranjang tetap kosong (no-op) |
| U-C-04 | Tambah item sama → qty naik | `add` 2× part sama | Qty = 2, `totalPrice` = 2×price |
| U-C-05 | Cap stok: qty tidak melebihi stok | `add` 6× part `stock: 3` | Qty berhenti di 3 |
| U-C-06 | Cap global 99 | Part `stock: 500`, `add` berulang | Qty berhenti di 99 |
| U-C-07 | Increment di atas cap no-op | Qty sudah = cap, `increment()` | Qty tetap |
| U-C-08 | Decrement qty > 1 → qty turun | `add` 3× lalu `decrement()` | Qty = 2 |
| U-C-09 | Decrement di qty 1 → item terhapus | `add` 1× lalu `decrement()` | Item hilang, `isEmpty` = true |
| U-C-10 | Remove menghapus item | `add` 2 part, `remove(id1)` | Sisa 1 part |
| U-C-11 | Clear mengosongkan semua | 2 item, `clear()` | Kosong, `totalCount` = 0 |
| U-C-12 | ClearLocal hanya bersihkan memori | (mock DB terpasang) `clearLocal()` | Kosong; pemanggilan DB **tidak** terjadi (verify with mocktail) |
| U-C-13 | Total price akumulasi | 2 part beda harga/qty | `totalPrice` = Σ subtotal |
| U-C-14 | `notifyListeners` terpanggil saat add/remove | Pasang listener hitungan | Hitungan bertambah tiap mutasi |
| U-C-15 | Load cart user null → bersih | `loadCartFromDatabase()` tanpa login | Tidak throw, keranjang kosong |

### 6.3 CSV Export & Omset (`sales_report_screen.dart`, setelah refactor T3)

| ID | Kasus | Input | Expected result |
|---|---|---|---|
| U-V-01 | Field biasa dibungkus kutip | `"Budi"` | `"Budi"` |
| U-V-02 | Koma di dalam field aman | `"Budi, S.Pd"` | `"Budi, S.Pd"` (1 kolom saat di-parse) |
| U-V-03 | Kutip ganda diduplikasi | `He said "hi"` | `"He said ""hi"""` |
| U-V-04 | Neutralisasi formula: `=` | `=1+1` | `"'=1+1"` |
| U-V-05 | Neutralisasi formula: `+` | `+6281234567` | `"+6281234567` |
| U-V-06 | Neutralisasi formula: `-` | `-2+3+cmd` | `"-2+3+cmd` |
| U-V-07 | Neutralisasi formula: `@` | `@SUM(A1)` | `"'@SUM(A1)` |
| U-V-08 | Neutralisasi tab/CR di awal | `\tABS` | `"\tABS` (diberi prefix ') |
| U-V-09 | String kosong aman | `""` | `""` (tanpa prefix, tidak error) |
| U-V-10 | Header CSV benar | `_generateCsv()` | Baris 1 persis `ID Pesanan,Tanggal,Pelanggan,Status Pesanan,Status Pembayaran,Total Nilai` |
| U-V-11 | Baris data = jumlah order | 3 order fixture | 1 header + 3 baris |
| U-V-12 | Format tanggal valid | `created_at` valid ISO | Ter-format `yyyy-MM-dd HH:mm:ss` (toLocal) |
| U-V-13 | Tanggal tidak valid → kolom kosong | `created_at: "abc"` | Kolom tanggal `""` (kosong — bukan `-`, karena `-` di awal cell memicu neutralisasi formula & menampilkan apostrof) |
| U-V-14 | Total 2 desimal | `total: 15000` | `15000.00` |
| U-V-15 | **Omset hanya verified & bukan cancelled** | Verified+completed=100k; verified+**cancelled**=50k; uploaded+pending=75k | Omset = **100.000** (kasus regresi bug "atau" lama) |
| U-V-16 | Omset kosong | Tidak ada order verified | `0.0` |

---

## 7. Rencana Widget Test

File: `test/<screen>_test.dart`. Catatan: screen yang langsung memanggil `Supabase.instance.client` perlu inisialisasi dummy Supabase (T2) atau mock client sebelum `pumpWidget`.

| ID | Screen | Kasus | Expected |
|---|---|---|---|
| W-01 | Auth | Halaman login render field & tombol | TextField username/email & password tampil, tombol login aktif |
| W-02 | Auth | Login dengan field kosong | Validasi form muncul, tidak memanggil auth |
| W-03 | Splash | Splash tampil lalu navigasi | Splash muncul, navigasi ke login/home sesuai sesi |
| W-04 | Katalog | Daftar part tampil dari data mock | Nama, part number, harga tampil per item |
| W-05 | Katalog | Search mengetik "knalpot" | List terfilter & terurut relevansi |
| W-06 | Katalog | Part stok 0 → tombol add disabled/greyed | Tidak bisa ditambahkan |
| W-07 | Cart | Tambah item → badge jumlah keranjang naik | Badge = `totalCount` |
| W-08 | Cart | Keranjang kosong → tampil empty state | Ilustrasi/teks "keranjang kosong" + tombol ke katalog |
| W-09 | Cart | Tombol +/- berfungsi | Qty & subtotal ikut berubah |
| W-10 | Checkout | Form kosong → tombol checkout tidak submit | Error validasi tampil |
| W-11 | Checkout | Pilih kurir → total berubah | Total = subtotal + ongkir |
| W-12 | Payment | Upload tanpa memilih foto | Snackbar error, tidak memanggil storage |
| W-13 | Order History | Daftar order tampil & filter status | Order terfilter sesuai status dipilih |
| W-14 | Admin | Form tambah part tanpa foto/nama | Validasi muncul, tidak ada insert |
| W-15 | Admin Orders | Ubah status → optimistic update | Status berubah di UI + snackbar sukses |
| W-16 | Report | Pilih rentang tanggal invalid (end < start) | Ditangani (pesan/tidak crash) |
| W-17 | Semua | Navigasi peran: login sebagai admin | Menu admin (CRUD part, kelola pesanan, laporan) tampil; customer tidak melihat menu ini |

---

## 8. Rencana Integration Test (Supabase lokal/staging)

File: `integration_test/<flow>_test_test.dart`. Setup: `supabase start` + apply `supabase_phase2_migration.sql` + seed. Test dijalankan berurutan per flow, dibersihkan setelahnya (cleanup order).

**Akun test yang disiapkan (seed):**

| Akun | Role | Untuk |
|---|---|---|
| `cust1@test.dev` | customer | Alur pembelian |
| `cust2@test.dev` | customer | Isolasi data antar user |
| `admin1@test.dev` | admin | CRUD, verifikasi, laporan, update stok |

> **Catatan (17 Okt 2026):** Role `warehouse` dihapus dari sistem. Fitur update stok kini dilakukan oleh `admin`. Akun `wh1@test.dev` tidak lagi digunakan.

| ID | Flow | Langkah singkat | Expected |
|---|---|---|---|
| I-01 | Register → login | Register akun baru, logout, login pakai username | Login sukses, role = customer, masuk katalog |
| I-02 | Login via username | Login `cust1` (tanpa @email) | Sukses (RPC `get_email_by_username`) |
| I-03 | Login gagal | Password salah | Pesan error jelas, tidak ada crash |
| I-04 | Cart persist | Tambah 2 item → tutup app (re-init) → buka | Keranjang sama seperti sebelumnya (tersimpan di DB) |
| I-05 | **Checkout end-to-end** | Checkout 2 item | Order `pending`, `order_items` benar, **stok berkurang**, keranjang kosong |
| I-06 | Checkout stok habis | Dua device/user checkout stok terakhir bersamaan | Order kedua gagal/ditolak, stok tidak minus (transaction RPC) |
| I-07 | Upload bukti | Upload foto → submit | `payment_status='uploaded'`, path tersimpan, file ada di bucket `payment-proofs` |
| I-08 | Verifikasi admin | Admin verifikasi order I-05 | `payment_status='verified'` |
| I-09 | Tolak pembayaran | Admin reject order lain | Status sesuai desain (rejected + alasan bila ada) |
| I-10 | Update stok admin | Admin ubah stok part | Stok berubah & tampil di katalog customer (realtime) |
| I-11 | CRUD admin | Admin tambah part + foto → edit → hapus | Foto tersimpan di `part-images`, data konsisten |
| I-12 | Riwayat | Customer buka riwayat | Hanya order miliknya, status ter-update realtime |
| I-13 | Laporan + CSV | Admin filter tanggal/status → export | Data sesuai filter; hasil CSV lolos parser (kolom utuh) |
| I-14 | Realtime cart | Dua sesi login akun sama, tambah item di sesi A | Sesi B ter-update otomatis |

---

## 9. Rencana Pengujian Keamanan

Pengujian keamanan dilakukan **2 cara**: (a) otomatis via integration test memakai token 3 role berbeda, (b) manual via SQL editor/API.

### 9.1 RLS Matrix Test

Setiap baris = 1 test. Metode: panggil query dengan token role tsb, expected di kolom.

| ID | Tabel/Aksi | Sebagai customer | Sebagai admin |
|---|---|---|---|
| S-01 | `parts` select | ✅ boleh | ✅ boleh |
| S-02 | `parts` insert | ❌ ditolak | ✅ boleh |
| S-03 | `parts` update (nama/harga) | ❌ ditolak | ✅ boleh |
| S-04 | `parts` update stock | ❌ ditolak | ✅ boleh |
| S-05 | `parts` delete | ❌ ditolak | ✅ boleh |
| S-06 | `cart_items` baca | ✅ hanya miliknya sendiri | ❌ ditolak |
| S-07 | `cart_items` tulis | ✅ user_id = sendiri | ❌ |
| S-08 | `cart_items` user lain | ❌ tidak bisa baca/tulis cart `cust2` | — |
| S-09 | `orders` select | ✅ hanya miliknya | ✅ semua |
| S-10 | `orders` update status | ❌ ditolak | ✅ status + payment |
| S-11 | `order_items` | ✅ via ordernya sendiri | ✅ semua |
| S-12 | RPC `checkout_cart` | ✅ jalan dengan data sendiri | ✅ |
| S-13 | RPC `submit_payment_proof` | ✅ hanya order miliknya | ✅ |

> **Catatan (17 Okt 2026):** Role `warehouse` dihapus dari sistem. Kolom warehouse dihapus dari matrix ini. Update stok kini dilakukan oleh admin.

### 9.2 Keamanan Lainnya

| ID | Aspek | Kasus uji | Expected |
|---|---|---|---|
| S-20 | Anon key | Cek repo: `grep` string anon key di kode | Tidak ada hardcoded key/URL default; semua via `String.fromEnvironment` + `config/*.json` di-gitignore |
| S-21 | Signed URL | Buka bukti transfer di UI, salin URL | URL ber-**signature & expiry (5 menit)**, bukan public URL; setelah expired → 403 |
| S-22 | Akses bucket langsung | Coba akses object `payment-proofs` tanpa login (REST storage) | Ditolak (private bucket) |
| S-23 | CSV injection | Insert order dengan `shipping_name = "='cmd|calc'!A1"` → export CSV | Sel diawali `'` teks, **tidak** dieksekusi Excel (bukti: buka di LibreOffice/Excel, tidak muncul popup script) |
| S-24 | Auth gate | Akses route admin tanpa sesi / sesi customer | Dilempar ke login / ditolak masuk panel admin |
| S-25 | Manipulasi role | Ubah `profiles.role` milik sendiri via API jadi `admin` | ❌ Ditolak RLS (customer tidak punya UPDATE di profiles) |
| S-26 | Guest access | Tanpa login, buka katalog | Dibatasi (katalog publik ok, checkout/cart tertutup) |
| S-27 | Sesi kedaluwarsa | Hapus token, lanjutkan aksi | Arahkan ke login, tidak crash |

---

## 10. Rencana Non-Fungsional

| ID | NFR | Metode | Target / expected |
|---|---|---|---|
| N-01 | Performa search | `TfIdfSearch` dengan 500 part, `search()` 100× | Rata-rata < 50 ms per query (client-side) |
| N-02 | Performa load katalog | Stopwatch `pumpAndSettle` katalog + 50 part | Render < 2 detik di emulator standar |
| N-03 | Startup | Splash → home | Splash 2 detik, total < 4 detik ke katalog |
| N-04 | Realtime latency | Tambah item di sesi A, ukur sampai update sesi B | < 3 detik |
| N-05 | Offline / jaringan putus | Airplane mode saat buka katalog & saat add cart | Aplikasi tidak crash; pesan error jelas; state lokal konsisten (add optimistic, sync menyusul) |
| N-06 | Konsistensi stok | Refresh katalog setelah checkout | Stok tampil sesuai DB |
| N-07 | Jumlah data | Keranjang 20 item berbeda | Scroll mulus, total benar |
| N-08 | Accessibility dasar | Cek kontras/ukuran tap | Semua action button ≥ 48dp, label icon ada (tooltip/semantics) |
| N-09 | Rotasi layar | Rotasi di cart & checkout | State form tidak hilang |
| N-10 | Back navigation | Tombol back dari payment upload | Tidak keluar dari aplikasi tak terduga; pesan konfirmasi bila order belum bayar |

---

## 11. Checklist Pengujian Manual (untuk demo & laporan)

Jalankan per role, centang hasil. Skenario mengikuti alur di `docs/diagram/activity-diagram.mermaid`.

### Customer

| # | Skenario | Langkah | Expected | ✓/✗ |
|---|---|---|---|---|
| M-01 | Register & login | Daftar akun → logout → login username | Masuk katalog | |
| M-02 | Cari sparepart | Ketik "knalpot" | Hasil terurut relevansi | |
| M-03 | Detail produk | Klik produk | Foto, PN, harga, stok tampil | |
| M-04 | Tambah keranjang | Klik tambah 3× | Badge = 3, qty tidak lebih stok | |
| M-05 | Keranjang realtime | Buka 2 device akun sama | Sinkron live | |
| M-06 | Checkout | Isi nama, telepon, alamat, kurir | Order dibuat pending, stok berkurang | |
| M-07 | Upload bukti | Pilih foto transfer → submit | Snackbar sukses, status uploaded | |
| M-08 | Riwayat | Buka riwayat | Order muncul, status menunggu verifikasi | |

### Admin

| # | Skenario | Langkah | Expected | ✓/✗ |
|---|---|---|---|---|
| M-09 | Login admin | Login `admin1` | Panel admin tampil (CRUD part, kelola pesanan, laporan) | |
| M-10 | Update stok | Pilih part → ubah stok | Tersimpan; katalog customer terupdate | |
| M-11 | CRUD part | Tambah part + foto → edit → hapus | Konsisten di katalog | |
| M-12 | Verifikasi pembayaran | Verifikasi 1 order, reject 1 order | Status berubah sesuai | |
| M-13 | Laporan | Filter tanggal & status | Omset hanya order verified (tidak cancelled) | |
| M-14 | Export CSV | Copy → paste ke Excel | Kolom rapi, nama aneh tidak jadi rumus | |

> **Catatan (17 Okt 2026):** Role `warehouse` dihapus. Checklist warehouse (M-09 s/d M-12 lama) digabung ke admin. Update stok kini dilakukan oleh admin.

---

## 12. Manajemen Defek

| Severity | Definisi | SLA perbaikan |
|---|---|---|
| **Critical** | Kehilangan data, uang salah, stok minus, RLS bocor, app crash di jalur utama | Sebelum demo — wajib 0 |
| **High** | Fitur inti tidak berjalan sesuai expected (checkout gagal, verifikasi error) | Sebelum demo |
| **Medium** | Fitur sekunder bermasalah / UX membingungkan | Catat, perbaiki bila waktu cukup |
| **Low** | Kosmetik (teks, warna, spacing) | Backlog |

Form pelaporan bug (tulis di `docs/pengujian/bug-tracker.md` bila ditemukan):

```
[B-001] [Severity] Judul
- Terjadi di: device/OS/build
- Langkah reproduce: 1..n
- Expected: ...
- Actual: ...
- Bukti: screenshot/log
- Status: Open / Fixed / Verified
```

---

## 13. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| RPC `checkout_cart` / trigger tidak ada di file migrasi repo (hanya live di Supabase) | Integration test gagal di environment baru | Export ulang schema dari project & komit; atau tulis pgTAP test di SQL |
| Supabase lokal butuh Docker | Dev tanpa Docker tak bisa run integration test | Sediakan project staging terpisah + akun test |
| Realtime test flaky (jaringan) | False negative | Retry 1×, threshold longgar (< 3 detik), catat sebagai known-issue bila stabil |
| Test menyentuh data produksi | Data demo berantakan | Khusus akun `@test.dev`, project staging terpisah dari data asli |
| `image_picker` sulit diwidget-test | Test payment upload gagal | Mock picker plugin atau lewat integration test + file fixture |

---

## 14. Urutan Pelaksanaan

| Tahap | Kegiatan | Keluaran |
|---|---|---|
| 1 | Refactor testability T2 & T3; hapus `widget_test.dart` bawaan | Kode siap dites |
| 2 | Unit test (bagian 6) → `flutter test` | Laporan unit |
| 3 | Setup Supabase lokal + seed akun test & part | Environment integration |
| 4 | Widget test (bagian 7) | Laporan widget |
| 5 | Integration + RLS (bagian 8–9) | Bukti matrix keamanan |
| 6 | Non-fungsional (bagian 10) + checklist manual (bagian 11) | Checklist terisi |
| 7 | Rekap bug & exit criteria → materi demo & Q&A | Slide pengujian |

---

## Riwayat Eksekusi

| Tanggal | Perintah | Cakupan | Hasil | Bukti |
|---|---|---|---|---|
| 14 Okt 2026 | `flutter test` | Unit (TF-IDF, keranjang) + widget splash | **27/27 lulus** | [`bukti/test-otomatis-1-unit-widget.md`](bukti/test-otomatis-1-unit-widget.md) |
| 14 Okt 2026 | `flutter test` | Unit CSV export & omset (refactor T3: ekstraksi `csv_utils.dart`) | **43/43 lulus** (16 baru) | [`bukti/test-otomatis-2-csv-export.md`](bukti/test-otomatis-2-csv-export.md) |
| 14 Okt 2026 | `flutter analyze` | Seluruh `lib/` + `test/` | **No issues found** | — |
| 17 Okt 2026 | Manual (emulator) | Checklist customer M-01 s/d M-08 | 6 PASS, 1 SEBAGIAN (B-001), 1 tertunda (environment emulator) | [`bukti/checklist-manual-customer-m01-m08.md`](bukti/checklist-manual-customer-m01-m08.md) |
| 17 Okt 2026 | SQL Editor | Hapus role warehouse dari sistem | Akun `staffgudang` dihapus; test plan & RLS matrix disederhanakan | — |
| 17 Okt 2026 | `rls_check.ps1` | RLS matrix (customer + admin) | **11 PASS, 0 TEMUAN, 0 FAIL, 1 SKIP** (S-07 butuh customer2 opsional) | [`bukti/rls-check_2026-10-17_154923.txt`](bukti/rls-check_2026-10-17_154923.txt) |
| 17 Okt 2026 | Manual (emulator) | Checklist admin M-09 s/d M-14 | 5 PASS, 1 SEBAGIAN (M-12 realtime) | [`bukti/checklist-manual-admin-m09-m14.md`](bukti/checklist-manual-admin-m09-m14.md) |

---

## Lampiran A — Contoh Setup Unit Test CartModel (tanpa jaringan)

```dart
// test/cart_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oem_sparepart_catalog/cart_helper.dart';

void main() {
  setUpAll(() async {
    // URL dummy: currentUser akan null sehingga semua sync-DB ter-skip,
    // dan kita menguji logika lokal keranjang secara murni.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'dummy-for-test',
    );
  });

  setUp(CartModel.instance.clearLocal);

  test('U-C-04: menambah part yang sama menaikkan quantity', () async {
    final cart = CartModel.instance;
    await cart.add(partId: 'p1', name: 'Knalpot', price: 100.0, stock: 5);
    await cart.add(partId: 'p1', name: 'Knalpot', price: 100.0, stock: 5);

    expect(cart.items.single.quantity, 2);
    expect(cart.totalPrice, 200.0);
  });

  test('U-C-05: quantity tidak melebihi stok', () async {
    final cart = CartModel.instance;
    for (var i = 0; i < 6; i++) {
      await cart.add(partId: 'p2', name: 'Filter', price: 50.0, stock: 3);
    }
    expect(cart.items.single.quantity, 3);
  });

  test('U-C-09: decrement di quantity 1 menghapus item', () async {
    final cart = CartModel.instance;
    await cart.add(partId: 'p3', name: 'Oli', price: 30.0, stock: 2);
    await cart.decrement('p3');
    expect(cart.isEmpty, isTrue);
  });
});
```

## Lampiran B — Contoh RLS Test (integration_test, via token 3 role)

```dart
// integration_test/rls_matrix_test.dart
test('S-02: customer TIDAK BISA insert parts', () async {
  final client = await _loginAs('cust1@test.dev', 'password123');
  var blocked = false;
  try {
    await client.from('parts').insert({'name': 'HACK', 'price': 1});
  } on PostgrestException {
    blocked = true; // RLS menolak → expected
  }
  expect(blocked, isTrue,
      reason: 'RLS "Only full admin can insert parts" harus aktif');
});

test('S-04: admin boleh update parts, customer ditolak', () async {
  // Admin bisa update stock
  final adminClient = await _loginAs('admin1@test.dev', 'password123');
  await adminClient.from('parts').update({'stock': 42}).eq('id', partId);

  // Customer tidak bisa update stock
  final custClient = await _loginAs('cust1@test.dev', 'password123');
  var blocked = false;
  try {
    await custClient.from('parts').update({'stock': 42}).eq('id', partId);
  } on PostgrestException {
    blocked = true;
  }
  expect(blocked, isTrue, reason: 'RLS: customer tidak boleh update parts');
});
```
