import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'payment_upload_screen.dart';
import 'app_theme.dart';

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
                // Pertahankan order_items lama jika update event tidak menyertakannya
                final existingItems = _orders[idx]['order_items'];
                final updatedRecord = Map<String, dynamic>.from(updated);
                if (existingItems != null) {
                  updatedRecord['order_items'] = existingItems;
                }
                _orders[idx] = updatedRecord;
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

  String _formatDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pesanan'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: const BoxDecoration(
                            color: AppTheme.tint,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            size: 38,
                            color: AppTheme.red,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Belum ada pesanan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.heading,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Pesanan yang kamu buat akan muncul di halaman ini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppTheme.sub),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
                    final shortId = orderId.length > 8
                        ? orderId.substring(0, 8).toUpperCase()
                        : orderId.toUpperCase();
                    final total = (order['total'] as num? ?? 0).toDouble();

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

                    final isPaymentUploaded = paymentStatus == 'uploaded';
                    final isPaymentVerified = paymentStatus == 'verified';
                    final isPaymentRejected = paymentStatus == 'rejected';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ExpansionTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        collapsedShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        title: Row(
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
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDate(order['created_at']),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.heading,
                                  ),
                                ),
                              ],
                            ),
                            AppTheme.statusBadge(statusLabel, type: statusType),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 10),
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
                        children: [
                          const Divider(color: AppTheme.border, height: 1),
                          // List item
                          ...items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['part_name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.heading,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${item['quantity']} × ${AppTheme.formatRupiah((item['price'] as num? ?? 0))}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.sub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(color: AppTheme.border, height: 1),

                          // Alamat Pengiriman & Status Pembayaran Box
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Penerima & Alamat',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.heading,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${order['shipping_name'] ?? '-'} · ${order['shipping_phone'] ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.sub,
                                  ),
                                ),
                                Text(
                                  order['shipping_address'] ?? '-',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.sub,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Payment Status Box (sesuai Figma .payment)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAFAFA),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFECECE8),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isPaymentVerified
                                                  ? AppTheme.green
                                                  : isPaymentRejected
                                                      ? AppTheme.red
                                                      : isPaymentUploaded
                                                          ? AppTheme.info
                                                          : AppTheme.amber,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: isPaymentVerified
                                                      ? AppTheme.greenBg
                                                      : isPaymentRejected
                                                          ? AppTheme.tint
                                                          : AppTheme.amberBg,
                                                  blurRadius: 4,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isPaymentVerified
                                                      ? 'Pembayaran Terverifikasi'
                                                      : isPaymentUploaded
                                                          ? 'Bukti Terkirim'
                                                          : isPaymentRejected
                                                              ? 'Bukti Pembayaran Ditolak'
                                                              : 'Menunggu Bukti Bayar',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.heading,
                                                  ),
                                                ),
                                                Text(
                                                  isPaymentVerified
                                                      ? 'Pesanan sedang diproses'
                                                      : isPaymentUploaded
                                                          ? 'Akan diverifikasi oleh admin'
                                                          : isPaymentRejected
                                                              ? 'Foto bukti tidak valid, silakan upload ulang'
                                                              : 'Segera lakukan transfer dan upload bukti',
                                                  style: const TextStyle(
                                                    fontSize: 9.5,
                                                    color: AppTheme.sub,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!isPaymentVerified &&
                                          status != 'cancelled') ...[
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          height: 38,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  isPaymentUploaded
                                                      ? Colors.white
                                                      : AppTheme.red,
                                              foregroundColor:
                                                  isPaymentUploaded
                                                      ? AppTheme.heading
                                                      : Colors.white,
                                              side: isPaymentUploaded
                                                  ? const BorderSide(
                                                      color: AppTheme.border,
                                                    )
                                                  : null,
                                            ),
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      PaymentUploadScreen(
                                                    orderId: orderId,
                                                    totalAmount: total,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: Icon(
                                              isPaymentUploaded
                                                  ? Icons.check
                                                  : Icons.upload_outlined,
                                              size: 16,
                                              color: isPaymentUploaded
                                                  ? AppTheme.green
                                                  : Colors.white,
                                            ),
                                            label: Text(
                                              isPaymentUploaded
                                                  ? 'Ganti / Upload Ulang Bukti'
                                                  : 'Upload Bukti Transfer',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
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
