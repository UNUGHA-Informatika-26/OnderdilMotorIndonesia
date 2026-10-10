# Onderdil Motor Indonesia

Muhammad Azfa Eka Satria 23EO10001

Aplikasi OEM Sparepart Catalog adalah aplikasi mobile berbasis Flutter yang berfungsi sebagai katalog dan sistem penjualan sparepart (onderdil) motor OEM. Aplikasi ini terintegrasi dengan backend Supabase untuk menangani autentikasi, database relasional, sinkronisasi data secara realtime, serta penyimpanan file (foto produk & bukti pembayaran).

Aplikasi menggunakan sistem multi-role dengan tiga jenis pengguna:

Customer — dapat mencari sparepart (dengan algoritma pencarian TF-IDF), menambahkan barang ke keranjang belanja yang tersimpan di cloud, melakukan checkout beserta data pengiriman, mengunggah bukti transfer, dan memantau riwayat pesanan.
Staff Gudang (Warehouse) — dapat memperbarui jumlah stok fisik barang serta mengelola status pengiriman pesanan masuk, tanpa akses mengubah harga atau menghapus produk.
Admin Penuh — memiliki akses penuh: menambah, mengubah, dan menghapus produk (termasuk foto), memverifikasi atau menolak bukti pembayaran, serta melihat laporan penjualan dengan fitur filter tanggal/status dan ekspor CSV.
Keamanan data diterapkan menggunakan Row Level Security (RLS) di Supabase, sehingga setiap role hanya dapat mengakses data sesuai haknya. Tampilan aplikasi mengusung tema Racing Red dengan Material Design 3, responsif untuk platform mobile maupun web/desktop.


