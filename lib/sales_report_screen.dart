import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oem_sparepart_catalog/csv_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';

final _db = Supabase.instance.client;

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  final DateTime _endDate = DateTime.now();
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
          SnackBar(
            content: Text('Gagal memuat laporan: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalRevenue => salesRevenue(_reportData);

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  void _showExportSheet() {
    if (_reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data transaksi untuk diekspor.')),
      );
      return;
    }

    final csvContent = generateSalesCsv(_reportData);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sheet drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDDDDD),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Text(
                  'Export Laporan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.heading,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pilih format laporan untuk periode ini.',
                  style: TextStyle(fontSize: 11, color: AppTheme.sub),
                ),
                const SizedBox(height: 16),

                // Preview Box
                Container(
                  height: 100,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      csvContent,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontFamily: 'RobotoMono',
                        color: AppTheme.heading,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Button: Salin ke Clipboard
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: csvContent));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'CSV berhasil disalin! Siap dipaste ke Excel / Google Sheets.',
                          ),
                          backgroundColor: AppTheme.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text(
                      'Salin ke Clipboard (Excel Ready)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          // Filter Rentang & Status
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
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
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Periode Mulai',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F5357),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDate(_startDate),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.heading,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Pesanan',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F5357),
                        ),
                      ),
                      DropdownButton<String>(
                        value: _selectedStatus,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.heading,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Semua status')),
                          DropdownMenuItem(value: 'completed', child: Text('Selesai')),
                          DropdownMenuItem(value: 'pending', child: Text('Menunggu')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Dibatalkan')),
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2 Metrics Boxes (matching Figma .metrics)
          Row(
            children: [
              // Total Pesanan Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.tint,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          size: 18,
                          color: AppTheme.red,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Total Pesanan',
                        style: TextStyle(fontSize: 10, color: AppTheme.sub),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_reportData.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.heading,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Periode ini',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Omset Sukses Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.greenBg,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.bar_chart_rounded,
                          size: 18,
                          color: AppTheme.green,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Omset Sukses',
                        style: TextStyle(fontSize: 10, color: AppTheme.sub),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppTheme.formatRupiah(_totalRevenue),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.green,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Terverifikasi',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section Head
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transaksi Terbaru',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.heading,
                ),
              ),
              InkWell(
                onTap: _showExportSheet,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Export CSV',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // List Data Transaksi matching Figma .transactions
          _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _reportData.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Tidak ada transaksi pada periode ini.',
                          style: TextStyle(color: AppTheme.sub),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _reportData.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: AppTheme.border, height: 1),
                        itemBuilder: (context, i) {
                          final item = _reportData[i];
                          final id = (item['id'] ?? '').toString();
                          final shortId = id.length > 8
                              ? id.substring(0, 8).toUpperCase()
                              : id.toUpperCase();
                          final total = (item['total'] as num? ?? 0).toDouble();
                          final status = item['status'] as String? ?? 'pending';
                          final date = item['created_at'] != null
                              ? DateTime.tryParse(item['created_at'])?.toLocal()
                              : null;

                          final statusLabel = status == 'completed'
                              ? 'Selesai'
                              : status == 'cancelled'
                                  ? 'Dibatalkan'
                                  : 'Menunggu';

                          final statusType = status == 'completed'
                              ? 'success'
                              : status == 'cancelled'
                                  ? 'danger'
                                  : 'waiting';

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '#$shortId · ${item['shipping_name'] ?? '-'}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'RobotoMono',
                                        color: AppTheme.heading,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      date != null
                                          ? '${date.day}/${date.month}/${date.year}'
                                          : '-',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: AppTheme.sub,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      AppTheme.formatRupiah(total),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.green,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    AppTheme.statusBadge(
                                      statusLabel,
                                      type: statusType,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ],
      ),
      bottomNavigationBar: _buildAdminBottomNav(context, activeIndex: 2),
    );
  }

  Widget _buildAdminBottomNav(BuildContext context, {required int activeIndex}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xF5FFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xE5E0E0E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24191919),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildAdminNavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Sparepart',
            isActive: activeIndex == 0,
            onTap: () => Navigator.of(context).pop(),
          ),
          _buildAdminNavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Pesanan',
            isActive: activeIndex == 1,
            onTap: () => Navigator.of(context).pop(),
          ),
          _buildAdminNavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Laporan',
            isActive: activeIndex == 2,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildAdminNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 86,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.tint : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 28,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isActive
                    ? const [
                        BoxShadow(
                          color: Color(0x1FB71C1C),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color: isActive ? AppTheme.red : const Color(0xFF777B80),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? AppTheme.red : const Color(0xFF777B80),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
