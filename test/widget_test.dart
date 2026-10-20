// Widget test — Splash screen.
// Mengganti template bawaan Flutter (counter test) yang tidak relevan
// dengan aplikasi ini. Test case terkait: rencana-pengujian.md W-03.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oem_sparepart_catalog/splash_screen.dart';

void main() {
  testWidgets('Splash tampil 2 detik lalu pindah ke halaman berikutnya',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SplashScreen(next: _HalamanTujuan()),
    ));

    // Splash terlihat: ikon motor + judul aplikasi.
    expect(find.byIcon(Icons.two_wheeler), findsOneWidget);
    expect(find.text('OEM Parts Catalog'), findsOneWidget);

    // Majukan waktu 2 detik → Timer pemicu navigasi menyala,
    // lalu 1 detik lagi untuk menyelesaikan animasi transisi.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Halaman Tujuan'), findsOneWidget);
  });
}

class _HalamanTujuan extends StatelessWidget {
  const _HalamanTujuan();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Halaman Tujuan')));
  }
}
