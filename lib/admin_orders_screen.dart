import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sales_report_screen.dart';

final _db = Supabase.instance.client;

class AdminOrdersScreen extends StatefulWidget {
  final String role; // 'admin' atau 'warehouse'
  const AdminOrdersScreen({super.key, this.role = 'admin'});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _ordersStream =
      _db.from('orders').stream(primaryKey: ['id']).order(
            'created_at',
            ascending: false,
          );

  Future<void> _updateStatus(String orderId, String status) async {
    try {
      await _db.from('orders').update({'status': status}).eq('id', orderId);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: ${e.message}')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchItems(String orderId) async {
    final data = await _db.from('order_items').select().eq(
          'order_id',
          orderId,
        );
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> _updatePaymentStatus(String orderId, String status) async {
    try {
      await _db
          .from('orders')
          .update({'payment_status': status}).eq('id', orderId);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: ${e.message}')),
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
          child: InteractiveViewer(
            child: Image.network(signedUrl),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat bukti: $e')),
        );
      }
    }
  }

  String _paymentLabel(String status) {
    switch (status) {
      case 'uploaded':
        return 'Bukti Terkirim';
      case 'verified':
        return 'Terverifikasi';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Belum Bayar';
    }
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'uploaded':
        return Colors.blue;
      case 'verified':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey[700]!;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return 'Menunggu';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _formatDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isFullAdmin = widget.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(isFullAdmin ? 'Kelola Pesanan' : 'Pesanan (Staff Gudang)'),
        actions: [
          if (isFullAdmin)
            IconButton(
              tooltip: 'Laporan Penjualan',
              icon: const Icon(Icons.assessment_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SalesReportScreen()),
              ),
            ),
        ],
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
            return const Center(child: Text('Belum ada pesanan.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final order = orders[i];
              final orderId = order['id'].toString();
              final status = order['status'] as String? ?? 'pending';
              final paymentStatus =
                  order['payment_status'] as String? ?? 'pending';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ExpansionTile(
                  title: Text('Pesanan #${orderId.substring(0, 8)}'),
                  subtitle: Text(
                    '${_formatDate(order['created_at'])}  |  '
                    'Total: \$${(order['total'] as num).toStringAsFixed(2)}',
                  ),
                  trailing: Chip(
                    label: Text(
                      _statusLabel(status),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    backgroundColor: _statusColor(status),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  children: [
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchItems(orderId),
                      builder: (context, itemSnap) {
                        if (!itemSnap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: itemSnap.data!
                              .map(
                                (item) => ListTile(
                                  dense: true,
                                  title: Text(item['part_name'] ?? ''),
                                  trailing: Text(
                                    '${item['quantity']} x '
                                    '\$${(item['price'] as num).toStringAsFixed(2)}',
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dikirim ke: ${order['shipping_name'] ?? '-'}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(order['shipping_address'] ?? '-'),
                          Text(order['shipping_phone'] ?? '-'),
                          const SizedBox(height: 10),
                          Text(
                            'Status Pesanan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: [
                              _statusButton(orderId, 'pending', status),
                              _statusButton(orderId, 'completed', status),
                              _statusButton(orderId, 'cancelled', status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                'Status Pembayaran',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                  _paymentLabel(paymentStatus),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                                backgroundColor: _paymentColor(paymentStatus),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: [
                              // Bukti transfer hanya untuk admin (policy storage
                              // juga membatasi ini; warehouse cukup lihat status).
                              if (isFullAdmin)
                                OutlinedButton.icon(
                                  onPressed: () => _viewProof(
                                    order['payment_proof_path'] as String?,
                                  ),
                                  icon: const Icon(Icons.image_outlined),
                                  label: const Text('Lihat Bukti'),
                                ),
                              if (isFullAdmin && paymentStatus == 'uploaded') ...[
                                FilledButton.icon(
                                  onPressed: () => _updatePaymentStatus(
                                    orderId,
                                    'verified',
                                  ),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Verifikasi'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _updatePaymentStatus(
                                    orderId,
                                    'rejected',
                                  ),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Tolak',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statusButton(String orderId, String value, String current) {
    final selected = value == current;
    return OutlinedButton(
      onPressed: selected ? null : () => _updateStatus(orderId, value),
      child: Text(_statusLabel(value)),
    );
  }
}