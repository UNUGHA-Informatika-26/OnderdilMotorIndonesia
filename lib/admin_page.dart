import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_helper.dart';
import 'admin_orders_screen.dart';

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
        backgroundColor: error ? Colors.red[700] : null,
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
        if (mounted) _msg('Sparepart ditambahkan');
      } else {
        await _db.from('parts').update(result).eq('id', part['id']);
        if (mounted) _msg('Sparepart diperbarui');
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
        title: const Text('Hapus sparepart?'),
        content: Text('${part['name']} akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
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
    final roleTitle = 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: _username,
          builder: (context, snapshot) {
            final name = snapshot.data;
            return Text(
              name == null || name.isEmpty
                  ? '$roleTitle - Kelola Sparepart'
                  : '$roleTitle - $name',
            );
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Kelola Pesanan',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminOrdersScreen(role: widget.role),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => _db.auth.signOut(),
          ),
        ],
      ),
      floatingActionButton: _isFullAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
            )
          : null,
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
          if (parts.isEmpty) {
            return const Center(child: Text('Belum ada sparepart.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: parts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = parts[i];
              final price = (p['price'] as num?)?.toStringAsFixed(2) ?? '-';
              final imageUrl = p['image_url'] as String?;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  backgroundImage:
                      imageUrl == null ? null : NetworkImage(imageUrl),
                  child: imageUrl == null
                      ? const Icon(Icons.build_circle_outlined)
                      : null,
                ),
                title: Text(p['name'] ?? ''),
                subtitle: Text(
                  'PN: ${p['part_number']}  |  Stok: ${p['stock']}  |  Rp $price',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _isFullAdmin ? 'Edit' : 'Update Stok',
                      icon: Icon(
                        _isFullAdmin ? Icons.edit_outlined : Icons.inventory_2_outlined,
                      ),
                      onPressed: () => _openForm(p),
                    ),
                    if (_isFullAdmin)
                      IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _delete(p),
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
        // Staff gudang hanya mengupdate stok
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

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    final title = widget.part == null
        ? 'Tambah Sparepart'
        : widget.isFullAdmin
            ? 'Edit Sparepart'
            : 'Update Stok Sparepart';

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isFullAdmin) ...[
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildPreview(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: _saving ? null : _pickImage,
                              icon: const Icon(Icons.image_outlined),
                              label: const Text('Pilih Gambar'),
                            ),
                            if (_newImageBytes != null ||
                                (_existingImageUrl != null && !_imageRemoved))
                              TextButton.icon(
                                onPressed: _saving ? null : _removeImage,
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                label: const Text(
                                  'Hapus',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nama'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: _pn,
                    decoration: const InputDecoration(labelText: 'Part Number'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: _category,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Harga'),
                    validator: (v) =>
                        double.tryParse((v ?? '').replaceAll(',', '.')) == null
                            ? 'Isi angka yang valid'
                            : null,
                  ),
                ] else ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(widget.part?['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('PN: ${widget.part?['part_number']} | Kategori: ${widget.part?['category']}'),
                  ),
                  const Divider(),
                ],
                TextFormField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah Stok',
                    hintText: 'Masukkan stok terbaru di gudang',
                  ),
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? 'Isi angka bulat' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    if (_newImageBytes != null) {
      return Image.memory(_newImageBytes!, fit: BoxFit.cover);
    }
    if (_existingImageUrl != null && !_imageRemoved) {
      return Image.network(_existingImageUrl!, fit: BoxFit.cover);
    }
    return const Icon(
      Icons.build_circle_outlined,
      size: 40,
      color: Colors.blueAccent,
    );
  }
}