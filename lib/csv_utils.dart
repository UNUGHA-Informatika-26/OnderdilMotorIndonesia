// Utilitas export CSV & perhitungan omset laporan penjualan.
//
// Dipisahkan dari SalesReportScreen supaya logikanya berupa fungsi murni
// yang bisa diuji unit test (lihat test/csv_utils_test.dart).
// Test case: docs/pengujian/rencana-pengujian.md bagian 6.3 (U-V-01 s/d U-V-16).

/// Aman untuk CSV: semua field dibungkus tanda kutip (koma / kutip / baris
/// baru tidak merusak kolom), dan teks yang diawali `= + - @ \t \r` diberi
/// awalan `'` supaya tidak dieksekusi sebagai rumus saat dibuka di
/// Excel / Google Sheets. Nama penerima diisi bebas oleh customer,
/// jadi tanpa ini bisa disusupi rumus (CSV/formula injection).
String csvCell(String value) {
  var v = value;
  if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) v = "'$v";
  return '"${v.replaceAll('"', '""')}"';
}

/// Hasilkan isi CSV laporan penjualan: satu baris header + satu baris per order.
String generateSalesCsv(List<Map<String, dynamic>> orders) {
  final buffer = StringBuffer();
  // CSV Header
  buffer.writeln(
      'ID Pesanan,Tanggal,Pelanggan,Status Pesanan,Status Pembayaran,Total Nilai');

  for (final order in orders) {
    final id = (order['id'] ?? '').toString();
    final date = DateTime.tryParse((order['created_at'] ?? '').toString())
            ?.toLocal()
            .toString() ??
        '';
    final customer = (order['shipping_name'] ?? '-').toString();
    final status = (order['status'] ?? '-').toString();
    final payStatus = (order['payment_status'] ?? '-').toString();
    final total = (order['total'] as num? ?? 0).toDouble().toStringAsFixed(2);

    buffer.writeln(
      [id, date, customer, status, payStatus, total].map(csvCell).join(','),
    );
  }
  return buffer.toString();
}

/// Omset = uang yang benar-benar sudah diterima: pembayaran sudah
/// diverifikasi DAN pesanan tidak dibatalkan.
///
/// Catatan regresi: versi lama memakai "atau", sehingga pesanan yang sudah
/// dibayar lalu dibatalkan tetap ikut terhitung. Test U-V-15 menjaga ini
/// agar tidak kembali terulang.
double salesRevenue(List<Map<String, dynamic>> orders) {
  return orders.fold<double>(0.0, (sum, o) {
    if (o['payment_status'] == 'verified' && o['status'] != 'cancelled') {
      return sum + (o['total'] as num? ?? 0).toDouble();
    }
    return sum;
  });
}
