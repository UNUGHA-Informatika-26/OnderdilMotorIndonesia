import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart_helper.dart';
import 'payment_upload_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cart = CartModel.instance;
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

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
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
      final itemsPayload = _cart.items
          .map((i) => {'part_id': i.partId, 'quantity': i.quantity})
          .toList();

      final orderId = await db.rpc('checkout_cart', params: {
        'items': itemsPayload,
        'p_shipping_name': _nameController.text.trim(),
        'p_shipping_phone': _phoneController.text.trim(),
        'p_shipping_address': _addressController.text.trim(),
        'p_shipping_option_id': _selectedShippingId,
      }) as String;

      final total = _cart.totalPrice + _selectedShippingCost;
      _cart.clear();

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
      body: AnimatedBuilder(
        animation: _cart,
        builder: (context, _) {
          if (_cart.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = _cart.items;
          if (items.isEmpty) {
            return const Center(child: Text('Keranjang masih kosong.'));
          }
          return SingleChildScrollView(
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
                          '\$${item.price.toStringAsFixed(2)} x ${item.quantity} = \$${item.subtotal.toStringAsFixed(2)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Kurangi',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _cart.decrement(item.partId),
                            ),
                            Text('${item.quantity}'),
                            IconButton(
                              tooltip: 'Tambah',
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: item.quantity >=
                                      (item.stock < CartModel.maxQuantityPerItem
                                          ? item.stock
                                          : CartModel.maxQuantityPerItem)
                                  ? null
                                  : () => _cart.increment(item.partId),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- Alamat pengiriman ---
                  const Text(
                    'Alamat Pengiriman',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Penerima',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Telepon',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Alamat Lengkap',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),

                  // --- Pilihan ongkir ---
                  const Text(
                    'Metode Pengiriman',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _shippingOptionsFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        );
                      }
                      final options = snapshot.data!;
                      if (options.isEmpty) {
                        return const Text(
                          'Belum ada metode pengiriman tersedia.',
                        );
                      }
                      _selectedShippingId ??= options.first['id'] as String;
                      _selectedShippingCost =
                          (options.first['cost'] as num).toDouble();

                      return DropdownButtonFormField<String>(
                        initialValue: _selectedShippingId,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: options
                            .map(
                              (o) => DropdownMenuItem(
                                value: o['id'] as String,
                                child: Text(
                                  '${o['name']} — \$${(o['cost'] as num).toStringAsFixed(2)}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          final selected = options.firstWhere(
                            (o) => o['id'] == value,
                          );
                          setState(() {
                            _selectedShippingId = value;
                            _selectedShippingCost =
                                (selected['cost'] as num).toDouble();
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // --- Ringkasan & checkout ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal'),
                      Text('\$${_cart.totalPrice.toStringAsFixed(2)}'),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ongkir'),
                      Text('\$${_selectedShippingCost.toStringAsFixed(2)}'),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '\$${(_cart.totalPrice + _selectedShippingCost).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _checkingOut ? null : _checkout,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _checkingOut
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Checkout'),
                    ),
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