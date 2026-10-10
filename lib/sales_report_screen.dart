import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _db = Supabase.instance.client;

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedStatus = 'all'; // all, completed, pending, cancelled
  bool _isLoading = false;
  List<Map<String, dynamic>> _reportData = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      // Batas tanggal dihitung dalam waktu lokal lalu dikirim sebagai UTC.
      // Tanpa ini, database membaca "00:00" sebagai jam UTC, sehingga
      // pesanan jam 00:00-07:00 WIB masuk ke hari yang salah.
      final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final endExclusive =
          DateTime(_endDate.year, _endDate.month, _endDate.day)
              .add(const Duration(days: 1));

      var filterBuilder = _db
          .from('orders')
          .select('id, user_id, status, payment_status, total, created_at, shipping_name')
          .gte('created_at', start.toUtc().toIso8601String())
          .lt('created_at', endExclusive.toUtc().toIso8601String());

      if (_selectedStatus != 'all') {
        filterBuilder = filterBuilder.eq('status', _selectedStatus);
      }

      final data = await filterBuilder.order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _reportData = List<Map<String, dynamic>>.from(data as List);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat laporan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalRevenue {
    return _reportData.fold<double>(0.0, (sum, o) {
      // Omset = uang yang benar-benar sudah diterima: pembayaran sudah
      // diverifikasi DAN pesanan tidak dibatalkan. (Versi lama memakai
      // "atau", sehingga pesanan yang sudah dibayar lalu dibatalkan
      // tetap ikut terhitung.)
      if (o['payment_status'] == 'verified' && o['status'] != 'cancelled') {
        return sum + (o['total'] as num? ?? 0).toDouble();
      }
      return sum;
    });
  }

  String _generateCsv() {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('ID Pesanan,Tanggal,Pelanggan,Status Pesanan,Status Pembayaran,Total Nilai');

    for (final order in _reportData) {
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
        [id, date, customer, status, payStatus, total].map(_csvCell).join(','),
      );
    }
    return buffer.toString();
  }

  /// Aman untuk CSV: semua field diberi tanda kutip (koma / kutip / baris
  /// baru tidak merusak kolom), dan teks yang diawali = + - @ diberi
  /// awalan ' supaya tidak dieksekusi sebagai rumus saat dibuka di
  /// Excel / Google Sheets. Nama penerima diisi bebas oleh customer,
  /// jadi tanpa ini bisa disusupi rumus (CSV/formula injection).
  String _csvCell(String value) {
    var v = value;
    if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) v = "'$v";
    return '"${v.replaceAll('"', '""')}"';
  }

  void _exportCsv() {
    if (_reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data pesanan untuk diekspor.')),
      );
      return;
    }

    final csvContent = _generateCsv();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Laporan (CSV)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Data: ${_reportData.length} transaksi'),
            Text('Omset Sukses: \$${_totalRevenue.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            const Text(
              'Anda dapat menyalin teks CSV di bawah atau klik tombol "Salin ke Clipboard" untuk paste ke Excel / Google Sheets:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              width: double.maxFinite,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  csvContent,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Salin ke Clipboard'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvContent));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV berhasil disalin! Siap dipaste ke Excel / Google Sheets.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.download),
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Card
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text('Dari: ${_formatDate(_startDate)}'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _startDate = picked);
                              _loadReport();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text('Sampai: ${_formatDate(_endDate)}'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _endDate = picked);
                              _loadReport();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedStatus,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                          DropdownMenuItem(value: 'completed', child: Text('Selesai (Completed)')),
                          DropdownMenuItem(value: 'pending', child: Text('Menunggu (Pending)')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Dibatalkan (Cancelled)')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedStatus = v);
                            _loadReport();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Summary Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withAlpha(50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Transaksi', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                        Text('${_reportData.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withAlpha(50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Omset Selesai', style: TextStyle(fontSize: 12, color: Colors.green)),
                        Text('\$${_totalRevenue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // List Data
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reportData.isEmpty
                    ? const Center(child: Text('Tidak ada transaksi pada periode ini.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _reportData.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = _reportData[i];
                          final id = (item['id'] ?? '').toString();
                          final total = (item['total'] as num? ?? 0).toDouble();
                          final status = item['status'] as String? ?? 'pending';
                          final date = item['created_at'] != null
                              ? DateTime.tryParse(item['created_at'])?.toLocal()
                              : null;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            title: Text('Pesanan #${id.length > 8 ? id.substring(0, 8) : id} - ${item['shipping_name'] ?? '-'}'),
                            subtitle: Text(
                              date != null
                                  ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
                                  : '-',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: status == 'completed'
                                        ? Colors.green
                                        : status == 'cancelled'
                                            ? Colors.red
                                            : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}