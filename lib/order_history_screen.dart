import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'payment_upload_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late final SupabaseClient _db;
  late final String _userId;
  RealtimeChannel? _channel;
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _db = Supabase.instance.client;
    _userId = _db.auth.currentUser!.id;
    _fetchOrders();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    final data = await _db
        .from('orders')
        .select('*, order_items(*)')
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    if (!mounted) return;
    setState(() {
      _orders = List<Map<String, dynamic>>.from(data as List);
      _loading = false;
    });
  }

  void _subscribeRealtime() {
    _channel = _db
        .channel('orders_user_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId,
          ),
          callback: (payload) {
            final updated = Map<String, dynamic>.from(payload.newRecord);
            if (!mounted) return;
            setState(() {
              final idx = _orders.indexWhere((o) => o['id'] == updated['id']);
              if (idx >= 0) {
                _orders[idx] = updated;
              }
            });
          },
        )
        .subscribe();
  }

  void _unsubscribe() {
    if (_channel != null) {
      _db.removeChannel(_channel!);
      _channel = null;
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

  String _paymentLabel(String status) {
    switch (status) {
      case 'uploaded':
        return 'Bukti Terkirim';
      case 'verified':
        return 'Pembayaran Terverifikasi';
      case 'rejected':
        return 'Bukti Ditolak';
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

  String _formatDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Pesanan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('Belum ada pesanan.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _orders.length,
                  itemBuilder: (context, i) {
                    final order = _orders[i];
                    final items = List<Map<String, dynamic>>.from(
                      order['order_items'] as List? ?? [],
                    );
                    final status = order['status'] as String? ?? 'pending';
                    final paymentStatus =
                        order['payment_status'] as String? ?? 'pending';
                    final orderId = order['id'].toString();

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ExpansionTile(
                        title: Text('Pesanan #${orderId.substring(0, 8)}'),
                        subtitle: Text(
                          '${_formatDate(order['created_at'])}  |  '
                          'Total: Rp ${(order['total'] as num).toStringAsFixed(2)}',
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
                          ...items.map(
                            (item) => ListTile(
                              dense: true,
                              title: Text(item['part_name'] ?? ''),
                              trailing: Text(
                                '${item['quantity']} x '
                                'Rp ${(item['price'] as num).toStringAsFixed(2)}',
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dikirim ke: ${order['shipping_name'] ?? '-'}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(order['shipping_address'] ?? '-'),
                                Text(order['shipping_phone'] ?? '-'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('Status Pembayaran: '),
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
                                if (paymentStatus == 'pending' ||
                                    paymentStatus == 'rejected') ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => PaymentUploadScreen(
                                            orderId: orderId,
                                            totalAmount:
                                                (order['total'] as num).toDouble(),
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.upload_outlined),
                                    label: Text(
                                      paymentStatus == 'rejected'
                                          ? 'Upload Ulang Bukti'
                                          : 'Upload Bukti Transfer',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
