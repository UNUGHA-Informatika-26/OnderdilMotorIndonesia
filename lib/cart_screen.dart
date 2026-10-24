import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart_helper.dart';
import 'payment_upload_screen.dart';
import 'bloc/bloc.dart';
import 'main.dart' show cartBloc;

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _checkingOut = false;
  late final Future<List<Map<String, dynamic>>> _shippingOptionsFuture =
      _fetchShippingOptions();
  String? _selectedShippingId;
  double _selectedShippingCost = 0;

  Future<List<Map<String, dynamic>>> _fetchShippingOptions() async {
    final data = await Supabase.instance.client
        .from('shipping_options')
        .select()
        .eq('is_active', true)
        .order('cost');
    return List<Map<String, dynamic>>.from(data as List);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Widget _summaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isTotal ? null : Colors.grey[600],
                fontWeight: isTotal ? FontWeight.bold : null,
              ),
            ),
          ),
          Text(
            'Rp ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout(CartLoaded cartState) async {
    if (cartState.isEmpty) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedShippingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih metode pengiriman dulu')),
      );
      return;
    }

    setState(() => _checkingOut = true);
    final db = Supabase.instance.client;

    try {
      final itemsPayload = cartState.items
          .map((i) => {'part_id': i.partId, 'quantity': i.quantity})
          .toList();

      final orderId = await db.rpc('checkout_cart', params: {
        'items': itemsPayload,
        'p_shipping_name': _nameController.text.trim(),
        'p_shipping_phone': _phoneController.text.trim(),
        'p_shipping_address': _addressController.text.trim(),
        'p_shipping_option_id': _selectedShippingId,
      }) as String;

      final total = cartState.totalPrice + _selectedShippingCost;
      if (!mounted) return;
      cartBloc.events.add(const CartCleared());

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentUploadScreen(
            orderId: orderId,
            totalAmount: total,
          ),
        ),
      );
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal checkout: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keranjang')),
      body: StreamBuilder<CartState>(
        stream: cartBloc.state,
        initialData: cartBloc.currentState,
        builder: (context, snapshot) {
          final cartState = snapshot.data;
          if (cartState is CartLoading || cartState is CartInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (cartState is CartError) {
            return Center(child: Text('Error: ${cartState.message}'));
          }

          final cart = cartState as CartLoaded;
          final items = cart.items;
          if (items.isEmpty) {
            return const Center(child: Text('Keranjang masih kosong.'));
          }
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Daftar item ---
                  ...items.map(
                    (item) => Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          'Rp ${item.price.toStringAsFixed(2)} x ${item.quantity} = Rp ${item.subtotal.toStringAsFixed(2)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Kurangi',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => cartBloc.events.add(
                                CartItemDecremented(item.partId),
                              ),
                            ),
                            Text('${item.quantity}'),
                            IconButton(
                              tooltip: 'Nama',
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: item.quantity >=
                                      (item.stock < CartModel.maxQuantityPerItem
                                          ? item.stock
                                          : CartModel.maxQuantityPerItem)
                                  ? null
                                  : () => cartBloc.events.add(
                                        CartItemIncremented(item.partId),
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- Ringkasan ---
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ringkasan',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          _summaryRow('Subtotal', cart.subtotal),
                          _summaryRow('Ongkir', _selectedShippingCost),
                          _summaryRow(
                            'Total',
                            cart.totalPrice + _selectedShippingCost,
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // --- Metode pengiriman ---
                  const Text(
                    'Metode Pengiriman',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _shippingOptionsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final options = snapshot.data ?? [];
                      if (options.isEmpty) {
                        return const Text('Belum ada opsi pengiriman.');
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedShippingId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: UnderlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey)),
                        ),
                        hint: const Text('Pilih metode pengiriman'),
                        items: options
                            .map(
                              (opt) => DropdownMenuItem<String>(
                                value: (opt['id'] as num).toString(),
                                child: Text(
                                  '${opt['name']} — Rp ${(opt['cost'] as num).toStringAsFixed(2)}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          final opt = options.firstWhere(
                            (o) => (o['id'] as num).toString() == v,
                          );
                          setState(() {
                            _selectedShippingId = v;
                            _selectedShippingCost =
                                (opt['cost'] as num).toDouble();
                          });
                        },
                        onSaved: (v) => _selectedShippingId = v,
                        validator: (v) =>
                            v == null ? 'Pilih metode pengiriman' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Alamat pengiriman ---
                  const Text(
                    'Nama',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        border: UnderlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey)),
                        hintText: 'Nama penerima',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nomor Telepon',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        border: UnderlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey)),
                        hintText: 'Contoh: 081234567890',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Detail Alamat',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: TextField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        border: UnderlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey)),
                        hintText: 'Jl. ... No. ...',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Tombol checkout ---
                  FilledButton(
                    onPressed: _checkingOut ? null : () => _checkout(cart),
                    child: _checkingOut
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Checkout & Bayar'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}