import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sales_report_screen.dart';
import 'app_theme.dart';

final _db = Supabase.instance.client;

class AdminOrdersScreen extends StatefulWidget {
  final String role; // 'admin'
  const AdminOrdersScreen({super.key, this.role = 'admin'});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _ordersStream = _db
      .from('orders')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  Future<void> _updatePaymentStatus(String orderId, String status) async {
    try {
      await _db
          .from('orders')
          .update({'payment_status': status})
          .eq('id', orderId);
      if (status == 'verified') {
        // Otomatis ubah status order ke completed jika verifikasi sukses
        await _db.from('orders').update({'status': 'completed'}).eq('id', orderId);
      } else if (status == 'rejected') {
        // Otomatis ubah status order ke cancelled jika ditolak
        await _db.from('orders').update({'status': 'cancelled'}).eq('id', orderId);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: ${e.message}'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  Future<void> _viewProof(String? proofPath) async {
    if (proofPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada bukti transfer')),
      );
      return;
    }
    try {
      final signedUrl = await _db.storage
          .from('payment-proofs')
          .createSignedUrl(proofPath, 300); // berlaku 5 menit
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Bukti Transfer'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              InteractiveViewer(
                child: Image.network(
                  signedUrl,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat bukti: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  String _formatDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final m = (d.month >= 1 && d.month <= 12) ? months[d.month - 1] : '';
    return '${d.day} $m ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isFullAdmin = widget.role == 'admin';

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Kelola Pesanan'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada pesanan masuk.',
                style: TextStyle(color: AppTheme.sub),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final order = orders[i];
              final orderId = order['id'].toString();
              final shortId = orderId.length > 8
                  ? orderId.substring(0, 8).toUpperCase()
                  : orderId.toUpperCase();
              final status = order['status'] as String? ?? 'pending';
              final paymentStatus =
                  order['payment_status'] as String? ?? 'pending';
              final total = (order['total'] as num? ?? 0).toDouble();
              final shippingName = (order['shipping_name'] ?? 'Customer').toString();
              final proofPath = order['payment_proof_path'] as String?;

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

              final canVerify =
                  isFullAdmin && paymentStatus == 'uploaded' && status == 'pending';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: #ID + Name, Date, Status Chip
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#$shortId',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontFamily: 'RobotoMono',
                                  color: AppTheme.sub,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                shippingName,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.heading,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(order['created_at']),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.sub,
                                ),
                              ),
                            ],
                          ),
                          AppTheme.statusBadge(statusLabel, type: statusType),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Total Row
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppTheme.border,
                              width: 0.8,
                              style: BorderStyle.solid,
                            ),
                            bottom: BorderSide(
                              color: AppTheme.border,
                              width: 0.8,
                              style: BorderStyle.solid,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total pembayaran',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.sub,
                              ),
                            ),
                            Text(
                              AppTheme.formatRupiah(total),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Bukti Transfer Box matching Figma .proof
                      InkWell(
                        onTap: () => _viewProof(proofPath),
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppTheme.tint,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.receipt_outlined,
                                  size: 18,
                                  color: AppTheme.red,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      proofPath != null
                                          ? 'Bukti transfer.jpg'
                                          : 'Belum ada bukti',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.heading,
                                      ),
                                    ),
                                    Text(
                                      proofPath != null
                                          ? (paymentStatus == 'verified'
                                              ? 'Pembayaran telah diverifikasi'
                                              : 'Klik untuk melihat pratinjau')
                                          : 'Menunggu customer upload',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.sub,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (proofPath != null)
                                const Text(
                                  'Preview',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.red,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Verifikasi / Tolak Actions
                      if (canVerify) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                height: 38,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.red,
                                    backgroundColor: AppTheme.tint,
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _updatePaymentStatus(orderId, 'rejected'),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text(
                                    'Tolak',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 38,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.green,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _updatePaymentStatus(orderId, 'verified'),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text(
                                    'Verifikasi',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _buildAdminBottomNav(context, activeIndex: 1),
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
            onTap: () {},
          ),
          _buildAdminNavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Laporan',
            isActive: activeIndex == 2,
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const SalesReportScreen(),
              ),
            ),
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
