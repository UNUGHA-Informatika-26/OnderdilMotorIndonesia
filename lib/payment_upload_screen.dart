import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Info rekening tujuan transfer. Ganti sesuai rekening bisnis asli.
class BankInfo {
  static const bankName = 'Bank Jago';
  static const accountNumber = '9909 8832 8489 2341';
  static const accountHolder = 'PT. OMI Indonesia';
}

class PaymentUploadScreen extends StatefulWidget {
  final String orderId;
  final double totalAmount;

  const PaymentUploadScreen({
    super.key,
    required this.orderId,
    required this.totalAmount,
  });

  @override
  State<PaymentUploadScreen> createState() => _PaymentUploadScreenState();
}

class _PaymentUploadScreenState extends State<PaymentUploadScreen> {
  Uint8List? _proofBytes;
  String? _proofExt;
  bool _uploading = false;

  Future<void> _pickProof() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _proofBytes = bytes;
      _proofExt = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'jpg';
    });
  }

  Future<void> _submit() async {
    if (_proofBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih foto bukti transfer dulu')),
      );
      return;
    }
    setState(() => _uploading = true);
    final db = Supabase.instance.client;

    try {
      final uid = db.auth.currentUser!.id;
      final path =
          '$uid/${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}.$_proofExt';

      await db.storage.from('payment-proofs').uploadBinary(
            path,
            _proofBytes!,
            fileOptions: const FileOptions(upsert: true),
          );

      await db.rpc('submit_payment_proof', params: {
        'p_order_id': widget.orderId,
        'p_proof_path': path,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bukti transfer terkirim. Menunggu verifikasi admin.',
          ),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal upload: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transfer ke rekening berikut',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    _infoRow('Bank', BankInfo.bankName),
                    _infoRow('No. Rek', BankInfo.accountNumber),
                    _infoRow('A/N', BankInfo.accountHolder),
                    const Divider(height: 24),
                    _infoRow(
                      'Total',
                      '\$${widget.totalAmount.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload Bukti Transfer',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: _proofBytes != null
                  ? Image.memory(_proofBytes!, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(Icons.receipt_long_outlined, size: 48),
                    ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickProof,
              icon: const Icon(Icons.upload_outlined),
              label: Text(
                _proofBytes == null ? 'Pilih Foto' : 'Ganti Foto',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _uploading ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _uploading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kirim Bukti Transfer'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _uploading
                  ? null
                  : () => Navigator.of(context).popUntil(
                        (route) => route.isFirst,
                      ),
              child: const Text('Nanti saja, kirim bukti belakangan'),
            ),
          ],
        ),
      ),
    );
  }
}