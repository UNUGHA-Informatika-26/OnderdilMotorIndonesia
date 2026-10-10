import 'package:supabase_flutter/supabase_flutter.dart';

/// Ambil username user yang sedang login dari tabel `profiles`.
/// Kalau gagal atau kosong, fallback ke email.
Future<String> fetchCurrentUsername() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return '';

  try {
    final row = await client
        .from('profiles')
        .select('username')
        .eq('id', user.id)
        .single();
    final username = row['username'] as String?;
    if (username != null && username.trim().isNotEmpty) return username;
  } catch (_) {
    // abaikan, pakai fallback di bawah
  }
  return user.email ?? '';
}