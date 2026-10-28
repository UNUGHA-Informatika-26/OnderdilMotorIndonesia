import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_helper.dart';
import 'admin_orders_screen.dart';
import 'sales_report_screen.dart';
import 'app_theme.dart';

final _db = Supabase.instance.client;

class AdminPartsScreen extends StatefulWidget {
  final String role; // 'admin'
  const AdminPartsScreen({super.key, this.role = 'admin'});

  @override
  State<AdminPartsScreen> createState() => _AdminPartsScreenState();
}

class _AdminPartsScreenState extends State<AdminPartsScreen> {
  final _partsStream =
      _db.from('parts').stream(primaryKey: ['id']).order('name');
  late final Future<String> _username = fetchCurrentUsername();

  bool get _isFullAdmin => widget.role == 'admin';

  void _msg(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppTheme.red : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _openForm([Map<String, dynamic>? part]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PartFormDialog(part: part, isFullAdmin: _isFullAdmin),
    );
    if (result == null) return;

    try {
      if (part == null) {
        await _db.from('parts').insert(result);
        if (mounted) _msg('Sparepart berhasil ditambahkan');
      } else {
        await _db.from('parts').update(result).eq('id', part['id']);
        if (mounted) _msg('Sparepart berhasil diperbarui');
      }
    } on PostgrestException catch (e) {
      if (mounted) _msg('Gagal: ${e.message}', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> part) async {
    if (!_isFullAdmin) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus sparepart?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text('${part['name']} akan dihapus secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.sub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _db.from('parts').delete().eq('id', part['id']);
      if (mounted) _msg('Sparepart dihapus');
    } on PostgrestException catch (e) {
      if (mounted) _msg('Gagal: ${e.message}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: _username,
          builder: (context, snapshot) {
            final name = snapshot.data;
            return Text(
              name == null || name.isEmpty ? 'Panel Admin' : 'Admin · $name',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.heading,
              ),
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout, color: AppTheme.heading),
            onPressed: () => _db.auth.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _partsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final parts = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              // Admin Heading with FAB
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'INVENTORI',
                        style: TextStyle(
                          color: AppTheme.red,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Daftar Sparepart',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.heading,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),
                  if (_isFullAdmin)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.red,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Tambah',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              if (parts.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text(
                      'Belum ada sparepart dalam inventori.',
                      style: TextStyle(color: AppTheme.sub),
                    ),
                  ),
                )
              else
                // Inventory rows matching Figma .inventory-row
                ...parts.map((p) {
                  final price = (p['price'] as num?)?.toDouble() ?? 0;
                  final imageUrl = p['image_url'] as String?;
                  final stock = p['stock'] ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
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
                    child: Row(
                      children: [
                        // Thumbnail 58x58
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.two_wheeler,
                                    size: 28,
                                    color: AppTheme.red,
                                  ),
                                )
                              : const Icon(
                                  Icons.two_wheeler,
                                  size: 28,
                                  color: AppTheme.red,
                                ),
                        ),
                        const SizedBox(width: 12),

                        // Title, PN, Price & Stock
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: AppTheme.heading,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F3F2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${p['part_number']}',
                                  style: const TextStyle(
                                    fontFamily: 'RobotoMono',
                                    color: AppTheme.sub,
                                    fontSize: 8.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    AppTheme.formatRupiah(price),
                                    style: const TextStyle(
                                      color: AppTheme.green,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    ' · Stok $stock',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.sub,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Actions: Edit & Delete
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _openForm(p),
                              borderRadius: BorderRadius.circular(7),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: AppTheme.border),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: AppTheme.heading,
                                ),
                              ),
                            ),
                            if (_isFullAdmin) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _delete(p),
                                borderRadius: BorderRadius.circular(7),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppTheme.tint,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: AppTheme.red,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildAdminBottomNav(context, activeIndex: 0),
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
            onTap: () {},
          ),
          _buildAdminNavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Pesanan',
            isActive: activeIndex == 1,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminOrdersScreen(role: widget.role),
              ),
            ),
          ),
          _buildAdminNavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Laporan',
            isActive: activeIndex == 2,
            onTap: () => Navigator.of(context).push(
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

class _PartFormDialog extends StatefulWidget {
  final Map<String, dynamic>? part;
  final bool isFullAdmin;
  const _PartFormDialog({this.part, this.isFullAdmin = true});

  @override
  State<_PartFormDialog> createState() => _PartFormDialogState();
}

class _PartFormDialogState extends State<_PartFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.part?['name']);
  late final _pn = TextEditingController(text: widget.part?['part_number']);
  late final _price =
      TextEditingController(text: widget.part?['price']?.toString());
  late final _stock =
      TextEditingController(text: widget.part?['stock']?.toString());
  late final _category =
      TextEditingController(text: widget.part?['category']);

  String? _existingImageUrl;
  Uint8List? _newImageBytes;
  bool _imageRemoved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _existingImageUrl = widget.part?['image_url'] as String?;
  }

  @override
  void dispose() {
    _name.dispose();
    _pn.dispose();
    _price.dispose();
    _stock.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _newImageBytes = bytes;
      _imageRemoved = false;
    });
  }

  void _removeImage() {
    setState(() {
      _newImageBytes = null;
      _imageRemoved = true;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      if (!widget.isFullAdmin) {
        Navigator.pop(context, {
          'stock': int.parse(_stock.text),
        });
        return;
      }

      String? imageUrl = _existingImageUrl;

      if (_newImageBytes != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_pn.text.trim()}.jpg';
        await Supabase.instance.client.storage
            .from('part-images')
            .uploadBinary(
              fileName,
              _newImageBytes!,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        imageUrl = Supabase.instance.client.storage
            .from('part-images')
            .getPublicUrl(fileName);
      } else if (_imageRemoved) {
        imageUrl = null;
      }

      if (!mounted) return;
      Navigator.pop(context, {
        'name': _name.text.trim(),
        'part_number': _pn.text.trim(),
        'price': double.parse(_price.text.replaceAll(',', '.')),
        'stock': int.parse(_stock.text),
        'category': _category.text.trim(),
        'image_url': imageUrl,
      });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  Widget _buildField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
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
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, color: AppTheme.heading),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(fontSize: 13, color: AppTheme.sub),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
          validator: validator,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'INVENTORI',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.red,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.part == null
                              ? 'Tambah Sparepart'
                              : 'Edit Sparepart',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.heading,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Photo Upload Box (matching Figma .photo-upload)
                if (widget.isFullAdmin)
                  InkWell(
                    onTap: _saving ? null : _pickImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 110,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFC9C9C7),
                          style: BorderStyle.solid,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _newImageBytes != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(_newImageBytes!, fit: BoxFit.cover),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: InkWell(
                                    onTap: _removeImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _existingImageUrl != null && !_imageRemoved
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      _existingImageUrl!,
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: InkWell(
                                        onTap: _removeImage,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 32,
                                      color: AppTheme.red,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Unggah foto produk',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.heading,
                                      ),
                                    ),
                                    Text(
                                      'JPG atau PNG, maks. 2 MB',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.sub,
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),
                const SizedBox(height: 14),

                if (widget.isFullAdmin) ...[
                  _buildField(
                    label: 'Nama sparepart',
                    placeholder: 'Contoh: Kampas Rem Depan',
                    controller: _name,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  _buildField(
                    label: 'Part number (PN)',
                    placeholder: '00000-XXX-000',
                    controller: _pn,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  _buildField(
                    label: 'Kategori',
                    placeholder: 'Contoh: Mesin / Pengereman',
                    controller: _category,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  _buildField(
                    label: 'Harga (Rp)',
                    placeholder: 'Contoh: 185000',
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => double.tryParse(
                                (v ?? '').replaceAll(',', '.')) ==
                            null
                        ? 'Isi angka valid'
                        : null,
                  ),
                ],

                _buildField(
                  label: 'Jumlah Stok',
                  placeholder: '0',
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? 'Isi angka bulat' : null,
                ),

                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Simpan Sparepart',
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
    );
  }
}
