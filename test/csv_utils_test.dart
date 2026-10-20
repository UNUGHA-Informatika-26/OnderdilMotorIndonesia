// Unit test — Export CSV & omset laporan penjualan (lib/csv_utils.dart)
// Test case: docs/pengujian/rencana-pengujian.md bagian 6.3 (U-V-01 s/d U-V-16)
//
// U-V-15 adalah test regresi untuk bug omset lama (kondisi "atau" → "dan"):
// pesanan yang sudah diverifikasi tapi dibatalkan tidak boleh terhitung omset.
import 'package:flutter_test/flutter_test.dart';
import 'package:oem_sparepart_catalog/csv_utils.dart';

void main() {
  group('csvCell — escaping & proteksi formula (U-V-01 s/d U-V-09)', () {
    test('U-V-01: field biasa dibungkus kutip', () {
      expect(csvCell('Budi'), '"Budi"');
    });

    test('U-V-02: koma di dalam field tetap satu kolom', () {
      expect(csvCell('Budi, S.Pd'), '"Budi, S.Pd"');
    });

    test('U-V-03: kutip ganda diduplikasi', () {
      expect(csvCell('He said "hi"'), '"He said ""hi"""');
    });

    test('U-V-04: formula diawali = diberi awalan kutip satu', () {
      expect(csvCell('=1+1'), "\"'=1+1\"");
    });

    test('U-V-05: nomor telepon diawali + netral', () {
      expect(csvCell('+6281234567'), "\"'+6281234567\"");
    });

    test('U-V-06: ekspresi diawali - netral', () {
      expect(csvCell('-2+3+cmd'), "\"'-2+3+cmd\"");
    });

    test('U-V-07: fungsi Excel diawali @ netral', () {
      expect(csvCell('@SUM(A1)'), "\"'@SUM(A1)\"");
    });

    test('U-V-08: karakter kontrol (tab) di awal netral', () {
      expect(csvCell('\tABS'), "\"'\tABS\"");
    });

    test('U-V-09: string kosong aman', () {
      expect(csvCell(''), '""');
    });
  });

  // Fixture 3 order yang mencakup tiga skenario status pembayaran.
  final orders = <Map<String, dynamic>>[
    {
      'id': 'ORD-001',
      'created_at': '2026-10-01T10:30:00+07:00',
      'shipping_name': 'Budi',
      'status': 'completed',
      'payment_status': 'verified',
      'total': 100000,
    },
    {
      'id': 'ORD-002',
      'created_at': '2026-10-02T08:00:00+07:00',
      'shipping_name': 'Siti',
      'status': 'cancelled',
      'payment_status': 'verified',
      'total': 50000,
    },
    {
      'id': 'ORD-003',
      'created_at': '2026-10-03T20:15:00+07:00',
      'shipping_name': 'Andi',
      'status': 'pending',
      'payment_status': 'uploaded',
      'total': 75000,
    },
  ];

  group('generateSalesCsv — struktur & format (U-V-10 s/d U-V-14)', () {
    test('U-V-10: header CSV persis sesuai spesifikasi', () {
      final csv = generateSalesCsv([]);
      expect(
          csv.split('\n').first,
          'ID Pesanan,Tanggal,Pelanggan,Status Pesanan,Status Pembayaran,'
          'Total Nilai');
    });

    test('U-V-11: jumlah baris = 1 header + jumlah order', () {
      final rows = generateSalesCsv(orders).trim().split('\n');
      expect(rows.length, 4);
    });

    test('U-V-12: tanggal valid terformat lokal (aman lintas timezone)', () {
      final expected =
          DateTime.parse('2026-10-01T10:30:00+07:00').toLocal().toString();
      expect(generateSalesCsv(orders), contains('"$expected"'));
    });

    test('U-V-13: tanggal tidak valid → kolom tanggal kosong', () {
      final csv = generateSalesCsv([
        {
          'id': 'ORD-004',
          'created_at': 'abc',
          'shipping_name': 'Coba',
          'status': 'pending',
          'payment_status': 'pending',
          'total': 0,
        },
      ]);
      expect(csv, contains('"ORD-004","",'));
    });

    test('U-V-14: total selalu diformat 2 desimal', () {
      final csv = generateSalesCsv([
        {
          'id': 'ORD-005',
          'created_at': '2026-10-04T12:00:00Z',
          'shipping_name': 'X',
          'status': 'completed',
          'payment_status': 'verified',
          'total': 15000,
        },
      ]);
      expect(csv, contains('"15000.00"'));
    });
  });

  group('salesRevenue — perhitungan omset (U-V-15 s/d U-V-16)', () {
    test('U-V-15: hanya verified & bukan cancelled yang dihitung omset',
        () {
      // 100.000 (verified + completed) → masuk
      //  50.000 (verified + cancelled)  → TIDAK (regresi bug "atau" lama)
      //  75.000 (uploaded + pending)    → TIDAK
      expect(salesRevenue(orders), 100000.0);
    });

    test('U-V-16: tanpa order → omset 0', () {
      expect(salesRevenue([]), 0.0);
    });
  });
}
