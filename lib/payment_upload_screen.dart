import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';

/// Info rekening tujuan transfer
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
        const SnackBar(
          content: Text('Pilih foto bukti transfer terlebih dahulu'),
          backgroundColor: AppTheme.red,
        ),
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
          backgroundColor: AppTheme.green,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upload: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _infoRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.sub),
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.heading,
                ),
              ),
              if (copyable) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value.replaceAll(' ', '')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nomor rekening disalin'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.copy,
                    size: 15,
                    color: AppTheme.red,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Bukti Transfer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bank Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transfer ke Rekening Resmi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.heading,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _infoRow('Bank Tujuan', BankInfo.bankName),
                  _infoRow('No. Rekening', BankInfo.accountNumber, copyable: true),
                  _infoRow('Atas Nama', BankInfo.accountHolder),
                  const Divider(color: AppTheme.border, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Bayar',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.sub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        AppTheme.formatRupiah(widget.totalAmount),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Photo Upload Area (sesuai Figma .photo-upload)
            InkWell(
              onTap: _uploading ? null : _pickProof,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 170,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _proofBytes != null ? AppTheme.red : AppTheme.border,
                    style: BorderStyle.solid,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _proofBytes != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_proofBytes!, fit: BoxFit.cover),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ganti Foto',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
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
                            size: 44,
                            color: AppTheme.red,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Unggah foto bukti transfer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.heading,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'JPG atau PNG, maks. 2 MB',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.sub,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _submit,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: _uploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Kirim Bukti Transfer',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _uploading
                  ? null
                  : () => Navigator.of(context).popUntil(
                        (route) => route.isFirst,
                      ),
              child: const Text(
                'Nanti saja, kirim bukti belakangan',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.sub,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
