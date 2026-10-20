// Unit test — Pencarian TF-IDF (lib/search_helper.dart)
// Test case: docs/pengujian/rencana-pengujian.md bagian 6.1 (U-S-01 s/d U-S-11)
import 'package:flutter_test/flutter_test.dart';
import 'package:oem_sparepart_catalog/search_helper.dart';

void main() {
  final List<Map<String, dynamic>> parts = [
    {'name': 'Knalpot Racing', 'part_number': 'KP-01', 'category': 'Exhaust'},
    {'name': 'Knalpot Standard', 'part_number': 'KS-02', 'category': 'Exhaust'},
    {'name': 'Filter Oli', 'part_number': 'FO-03', 'category': 'Engine'},
  ];

  TfIdfSearch sut() => TfIdfSearch(parts);

  List<String> partNumbers(List<Map<String, dynamic>> result) =>
      result.map((p) => p['part_number'].toString()).toList();

  group('TfIdfSearch — lib/search_helper.dart', () {
    test('U-S-01: query kosong mengembalikan semua part (urutan asli)', () {
      expect(partNumbers(sut().search('')),
          ['KP-01', 'KS-02', 'FO-03']);
    });

    test('U-S-02: query berisi spasi saja dianggap kosong', () {
      expect(sut().search('   ').length, 3);
    });

    test('U-S-03: pencarian case-insensitive', () {
      final result = partNumbers(sut().search('KNALPOT'));
      expect(result, unorderedEquals(['KP-01', 'KS-02']));
    });

    test('U-S-04: tanda baca dipisah (KP-01 cocok dengan "kp" dan "01")', () {
      final result = sut().search('KP-01');
      expect(partNumbers(result), ['KP-01']);
    });

    test('U-S-05: term langka (oli) mengalahkan term umum (knalpot)', () {
      // idf(oli) > idf(knalpot) karena lebih jarang → "Filter Oli" harus
      // unggul meski query juga memuat "knalpot".
      final result = partNumbers(sut().search('knalpot oli'));
      expect(result.first, 'FO-03',
          reason: 'skor TF-IDF term langka harus lebih tinggi');
    });

    test('U-S-06a: fallback substring untuk potongan kata', () {
      // "stan" bukan token utuh di dokumen mana pun, tapi substring dari
      // "standard" → tetap harus ketemu lewat fallback skor rendah.
      final result = partNumbers(sut().search('stan'));
      expect(result, ['KS-02']);
    });

    test('U-S-06b: hasil exact match selalu di atas fallback substring', () {
      final result = partNumbers(sut().search('racing stan'));
      expect(result, ['KP-01', 'KS-02'],
          reason: 'exact match (0.34) harus di atas fallback (0.01)');
    });

    test('U-S-07: tidak ada kecocokan → list kosong', () {
      expect(sut().search('bodykit ninja'), isEmpty);
    });

    test('U-S-08: field null di part tidak menyebabkan error', () {
      final List<Map<String, dynamic>> withNull = [
        {'name': null, 'part_number': 'X1', 'category': null},
      ];
      final result = TfIdfSearch(withNull).search('x1');
      expect(partNumbers(result), ['X1']);
    });

    test('U-S-09: daftar part kosong aman', () {
      expect(TfIdfSearch([]).search('apa pun'), isEmpty);
    });

    test('U-S-10: query sama dua kali → hasil identik (deterministik)', () {
      final a = partNumbers(sut().search('knalpot oli'));
      final b = partNumbers(sut().search('knalpot oli'));
      expect(a, b);
    });

    test('U-S-11: token berulang di query tidak mengubah hasil', () {
      final once = partNumbers(sut().search('knalpot'));
      final twice = partNumbers(sut().search('knalpot knalpot'));
      expect(twice, unorderedEquals(once));
    });
  });
}
