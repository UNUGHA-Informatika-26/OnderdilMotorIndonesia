import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart_helper.dart';
import 'payment_upload_screen.dart';
import 'bloc/bloc.dart';
import 'main.dart' show cartBloc;
import 'app_theme.dart';

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

  Future<void> _checkout(CartLoaded cartState) async {
    if (cartState.isEmpty) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_selectedShippingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kurir pengiriman terlebih dahulu'),
          backgroundColor: AppTheme.red,
        ),
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
          SnackBar(
            content: Text('Gagal checkout: ${e.message}'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  Widget _buildField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4F5357),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, color: AppTheme.heading),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(fontSize: 13, color: AppTheme.sub),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          validator: validator,
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
      ),
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

          // -----------------------------------------------------------------
          // EMPTY STATE
          // -----------------------------------------------------------------
          if (items.isEmpty) {
            return Center(
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
                        Icons.shopping_cart_outlined,
                        size: 38,
                        color: AppTheme.red,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Keranjang masih kosong',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.heading,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Temukan sparepart yang cocok untuk motor Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.sub,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 160,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Lihat Katalog'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final totalPayment = cart.totalPrice + _selectedShippingCost;

          // -----------------------------------------------------------------
          // CART LIST & CHECKOUT FORM
          // -----------------------------------------------------------------
          return Stack(
            children: [
              Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    // Daftar Item Kartu
                    ...items.map((item) {
                      final maxStock = item.stock < CartModel.maxQuantityPerItem
                          ? item.stock
                          : CartModel.maxQuantityPerItem;
                      final canIncrement = item.quantity < maxStock;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x08000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Thumbnail Foto Mini
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0EE),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.two_wheeler,
                                size: 30,
                                color: AppTheme.red,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Detail Item
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.heading,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${AppTheme.formatRupiah(item.price)} × ${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: AppTheme.sub,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppTheme.formatRupiah(item.subtotal),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Stepper [-] qty [+]
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.border),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () => cartBloc.events.add(
                                      CartItemDecremented(item.partId),
                                    ),
                                    child: Container(
                                      width: 28,
                                      height: 30,
                                      color: const Color(0xFFFAFAFA),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.remove,
                                        size: 14,
                                        color: AppTheme.heading,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 26,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.heading,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: canIncrement
                                        ? () => cartBloc.events.add(
                                              CartItemIncremented(item.partId),
                                            )
                                        : null,
                                    child: Container(
                                      width: 28,
                                      height: 30,
                                      color: canIncrement
                                          ? const Color(0xFFFAFAFA)
                                          : const Color(0xFFEEEEEE),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.add,
                                        size: 14,
                                        color: canIncrement
                                            ? AppTheme.heading
                                            : Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 10),

                    // Section Form Pengiriman
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Detail Pengiriman',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.heading,
                                ),
                              ),
                              Text(
                                'Wajib diisi',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.sub,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _buildField(
                            label: 'Nama penerima',
                            placeholder: 'Contoh: Andi Pratama',
                            controller: _nameController,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Nama penerima wajib diisi'
                                : null,
                          ),
                          _buildField(
                            label: 'Nomor telepon',
                            placeholder: 'Contoh: 081234567890',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Nomor telepon wajib diisi'
                                : null,
                          ),
                          _buildField(
                            label: 'Alamat lengkap',
                            placeholder: 'Jalan, nomor rumah, kecamatan, kota',
                            controller: _addressController,
                            maxLines: 2,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Alamat lengkap wajib diisi'
                                : null,
                          ),

                          // Kurir Pengiriman Dropdown
                          const Text(
                            'Kurir pengiriman',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F5357),
                            ),
                          ),
                          const SizedBox(height: 6),
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _shippingOptionsFuture,
                            builder: (context, optSnapshot) {
                              if (optSnapshot.connectionState !=
                                  ConnectionState.done) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final options = optSnapshot.data ?? [];
                              if (options.isEmpty) {
                                return const Text(
                                  'Belum ada opsi pengiriman tersedia.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.sub),
                                );
                              }

                              // Auto-select option pertama jika belum terpilih
                              if (_selectedShippingId == null && options.isNotEmpty) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted && _selectedShippingId == null) {
                                    final first = options.first;
                                    setState(() {
                                      _selectedShippingId = first['id'].toString();
                                      _selectedShippingCost =
                                          (first['cost'] as num).toDouble();
                                    });
                                  }
                                });
                              }

                              return DropdownButtonFormField<String>(
                                initialValue: _selectedShippingId ??
                                    (options.isNotEmpty
                                        ? options.first['id'].toString()
                                        : null),
                                isExpanded: true,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.heading,
                                ),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                                hint: const Text(
                                  'Pilih kurir pengiriman',
                                  style: TextStyle(fontSize: 13, color: AppTheme.sub),
                                ),
                                items: options.map((opt) {
                                  final cost = (opt['cost'] as num).toDouble();
                                  return DropdownMenuItem<String>(
                                    value: opt['id'].toString(),
                                    child: Text(
                                      '${opt['name']} · ${AppTheme.formatRupiah(cost)}',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  final opt = options.firstWhere(
                                    (o) => o['id'].toString() == v,
                                  );
                                  setState(() {
                                    _selectedShippingId = v;
                                    _selectedShippingCost =
                                        (opt['cost'] as num).toDouble();
                                  });
                                },
                                validator: (v) =>
                                    v == null ? 'Pilih kurir pengiriman' : null,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Sticky Bottom Total Bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppTheme.border)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x10000000),
                        blurRadius: 20,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Total bayar',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.sub,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppTheme.formatRupiah(totalPayment),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.green,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 140,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _checkingOut ? null : () => _checkout(cart),
                            child: _checkingOut
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Checkout',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
