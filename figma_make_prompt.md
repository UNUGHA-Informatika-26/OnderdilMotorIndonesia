Buat UI Mobile App Flutter Material 3 (390x844px) katalog sparepart motor OEM bertema Racing Red.

Design Tokens:
- Primary: #D32F2F (Automotive Red), Hover: #B71C1C, Tint: #FFEBEE
- Background: #FAFAFA, Surface: #FFFFFF, Border: #E0E0E0
- Text: #1A1C1E (Heading), #6C757D (Sub/PN), Success: #2E7D32 (Harga/Selesai)
- Font: Roboto/Inter. Corner: Card 12px, Button/Input 10px, Chip 16px.

Screen & Flow:
1. Login/Register: Logo motor, tab Masuk/Daftar, input email & password, button Primary Red.
2. Katalog Customer:
   - Header: Halo [User], icon history, cart badge merah, logout.
   - Search bar: Filter instan + icon search.
   - Grid 2-kolom: Foto produk (1:1), nama part, PN badge, harga bold hijau ($XX), stok, button "+ Tambah" (disabled jika stok 0).
3. Keranjang & Checkout:
   - List item: Foto mini, nama, subtotal ($price x qty), stepper [-] qty [+].
   - Form pengiriman: Nama, nomor telepon, alamat, kurir delivery.
   - Sticky bottom bar: Total bayar + button "Checkout".
4. Riwayat & Upload Bukti:
   - Card order: #ID, tanggal, total, status chip (Menunggu/Selesai/Dibatalkan).
   - Button "Upload Bukti Transfer" & status verifikasi bayar.
5. Panel Staff Gudang (warehouse):
   - Header: Staff Gudang. List part dengan tombol fokus "Update Stok" (tanpa tombol hapus/ubah harga).
   - Modal input jumlah stok fisik baru.
6. Panel Super Admin (admin):
   - Header: Admin + FAB "+ Tambah Sparepart" merah.
   - List sparepart: Aksi edit lengkap & delete merah.
   - Modal form: Foto, nama, PN, kategori, harga, stok.
7. Kelola Pesanan (Admin/Staff):
   - List order realtime, status chip, button preview bukti bayar.
   - Khusus Admin: Button hijau "Verifikasi" & merah "Tolak".
8. Laporan Penjualan (Admin):
   - Filter tanggal & status order.
   - 2 Box metrik: Total Pesanan & Omset Sukses.
   - List transaksi + modal "Export CSV / Salin Clipboard".
