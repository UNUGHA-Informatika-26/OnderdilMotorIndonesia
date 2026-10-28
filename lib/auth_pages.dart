import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';

GoTrueClient get _auth => Supabase.instance.client.auth;
SupabaseClient get _db => Supabase.instance.client;

void _showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: error ? AppTheme.red : null,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

enum AuthTab { masuk, daftar }

// ---------------------------------------------------------------------------
// LOGIN & REGISTER (UNIFIED FIGMA TABBED DESIGN)
// ---------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  final AuthTab initialTab;
  const LoginPage({super.key, this.initialTab = AuthTab.masuk});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late AuthTab _currentTab;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final input = _emailController.text.trim();
      String email;

      if (input.contains('@')) {
        // Sudah berupa email, pakai langsung.
        email = input;
      } else {
        // Berupa username: cari email yang cocok lewat function di database.
        final resolved = await _db.rpc(
          'get_email_by_username',
          params: {'p_username': input},
        ) as String?;
        if (resolved == null) {
          throw const AuthException('Username tidak ditemukan');
        }
        email = resolved;
      }

      await _auth.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );
      // Berhasil: AuthGate di main.dart otomatis pindah ke katalog / admin.
    } on AuthException catch (e) {
      if (mounted) _showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) _showMessage(context, 'Terjadi kesalahan: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await _auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {'username': _usernameController.text.trim()},
      );
      if (!mounted) return;

      if (res.session == null) {
        _showMessage(
          context,
          'Pendaftaran berhasil. Silakan login dengan akun barumu.',
        );
      } else {
        _showMessage(context, 'Pendaftaran berhasil!');
      }

      // Switch ke tab Masuk agar pengguna bisa langsung masuk
      setState(() {
        _currentTab = AuthTab.masuk;
        _passwordController.clear();
        _confirmController.clear();
      });
    } on AuthException catch (e) {
      if (mounted) _showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) _showMessage(context, 'Terjadi kesalahan: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    VoidCallback? onFieldSubmitted,
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
          obscureText: isPassword && _obscure,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, color: AppTheme.heading),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(fontSize: 13, color: AppTheme.sub),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: AppTheme.sub,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
          ),
          validator: validator,
          onFieldSubmitted: (_) => onFieldSubmitted?.call(),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMasuk = _currentTab == AuthTab.masuk;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.55, 1.0],
            colors: [Colors.white, Colors.white, AppTheme.tint],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Mark (Tilted Red Box with Bike Icon)
                    Transform.rotate(
                      angle: -3 * 3.141592653589793 / 180,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppTheme.red,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4DD32F2F),
                              blurRadius: 30,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.two_wheeler,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title: OMI (with red M)
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.heading,
                          letterSpacing: -1.5,
                        ),
                        children: [
                          TextSpan(text: 'O'),
                          TextSpan(
                            text: 'M',
                            style: TextStyle(color: AppTheme.red),
                          ),
                          TextSpan(text: 'I'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Onderdil Motor Indonesia',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.sub,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Auth Card with Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x171E1914),
                            blurRadius: 34,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Tabs: Masuk / Daftar
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _currentTab = AuthTab.masuk),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: isMasuk ? AppTheme.red : AppTheme.border,
                                            width: isMasuk ? 2 : 1,
                                          ),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Masuk',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isMasuk ? FontWeight.w800 : FontWeight.w600,
                                          color: isMasuk ? AppTheme.red : AppTheme.sub,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _currentTab = AuthTab.daftar),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: !isMasuk ? AppTheme.red : AppTheme.border,
                                            width: !isMasuk ? 2 : 1,
                                          ),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Daftar',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: !isMasuk ? FontWeight.w800 : FontWeight.w600,
                                          color: !isMasuk ? AppTheme.red : AppTheme.sub,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Fields for Register
                            if (!isMasuk)
                              _buildField(
                                label: 'Nama lengkap / Username',
                                placeholder: 'Contoh: andi_pratama',
                                controller: _usernameController,
                                validator: (v) => (v == null || v.trim().length < 3)
                                    ? 'Username minimal 3 karakter'
                                    : null,
                              ),

                            // Email or Username
                            _buildField(
                              label: isMasuk ? 'Username atau Email' : 'Email',
                              placeholder: isMasuk ? 'nama@email.com atau username' : 'nama@email.com',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email atau username wajib diisi';
                                }
                                if (!isMasuk && !v.contains('@')) {
                                  return 'Format email tidak valid';
                                }
                                return null;
                              },
                            ),

                            // Password
                            _buildField(
                              label: 'Password',
                              placeholder: 'Minimal 6 karakter',
                              controller: _passwordController,
                              isPassword: true,
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Password minimal 6 karakter'
                                  : null,
                              onFieldSubmitted: isMasuk ? _login : null,
                            ),

                            // Confirm Password for Register
                            if (!isMasuk)
                              _buildField(
                                label: 'Ulangi Password',
                                placeholder: 'Ketik ulang password',
                                controller: _confirmController,
                                isPassword: true,
                                validator: (v) => v != _passwordController.text
                                    ? 'Password tidak sama'
                                    : null,
                                onFieldSubmitted: _register,
                              ),

                            const SizedBox(height: 6),

                            // Primary Action Button (Red)
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _loading ? null : (isMasuk ? _login : _register),
                                child: _loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        isMasuk ? 'Masuk ke Akun' : 'Buat Akun',
                                        style: const TextStyle(
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
                    const SizedBox(height: 28),

                    // Copyright Footer
                    const Text(
                      'OEM verified parts · Garansi resmi',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8C8D8F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// REGISTER WRAPPER FOR BACKWARD COMPATIBILITY
// ---------------------------------------------------------------------------
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginPage(initialTab: AuthTab.daftar);
  }
}
