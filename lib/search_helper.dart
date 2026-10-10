import 'dart:math' as math;

/// Pencarian sederhana dengan skor TF-IDF, supaya hasil yang paling
/// relevan muncul di atas (bukan cuma cocok/tidak cocok).
///
/// Dokumen yang dipakai per sparepart: gabungan nama, part number,
/// dan kategori.
class TfIdfSearch {
  final List<Map<String, dynamic>> parts;
  final Map<int, Map<String, int>> _termCounts = {};
  final Map<int, int> _docLength = {};
  final Map<String, int> _docFreq = {};
  late final int _n;

  TfIdfSearch(this.parts) {
    _n = parts.length;
    for (var i = 0; i < parts.length; i++) {
      final tokens = _tokenize(_docText(parts[i]));
      final counts = <String, int>{};
      for (final t in tokens) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
      _termCounts[i] = counts;
      _docLength[i] = tokens.length;
      for (final t in counts.keys) {
        _docFreq[t] = (_docFreq[t] ?? 0) + 1;
      }
    }
  }

  String _docText(Map<String, dynamic> p) {
    return [p['name'], p['part_number'], p['category']]
        .where((e) => e != null)
        .join(' ');
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  double _idf(String term) {
    final df = _docFreq[term] ?? 0;
    // Smooth IDF (mirip scikit-learn): term yang jarang muncul di
    // banyak dokumen dapat bobot lebih tinggi.
    return math.log((_n + 1) / (df + 1)) + 1;
  }

  /// Cari & urutkan sparepart berdasarkan relevansi terhadap [query].
  /// Kalau query kosong, kembalikan daftar asli apa adanya.
  List<Map<String, dynamic>> search(String query) {
    final qTokens = _tokenize(query);
    if (qTokens.isEmpty) return parts;

    final scores = <int, double>{};
    for (var i = 0; i < parts.length; i++) {
      final counts = _termCounts[i]!;
      final length = _docLength[i]! == 0 ? 1 : _docLength[i]!;
      double score = 0;
      for (final t in qTokens) {
        final tf = (counts[t] ?? 0) / length;
        if (tf > 0) score += tf * _idf(t);
      }

      // Fallback: kalau tidak ada token yang cocok persis (mis. user
      // mengetik potongan kata), tetap tampilkan lewat pencarian
      // substring biasa, tapi diberi skor rendah supaya tetap di
      // bawah hasil yang cocok penuh.
      if (score == 0) {
        final text = _docText(parts[i]).toLowerCase();
        if (qTokens.any((t) => text.contains(t))) {
          score = 0.01;
        }
      }

      if (score > 0) scores[i] = score;
    }

    final ranked = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    return ranked.map((i) => parts[i]).toList();
  }
}