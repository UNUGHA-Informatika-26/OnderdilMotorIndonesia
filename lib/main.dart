import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'auth_pages.dart';
import 'admin_page.dart';
import 'profile_helper.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import 'search_helper.dart';
import 'splash_screen.dart';
import 'bloc/bloc.dart';
import 'app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Diambil dari --dart-define-from-file saat run/build (lihat
  // config/dev.json.example). Harus di-supply via:
  //   flutter run --dart-define-from-file=config/dev.json
  // atau di CI/CD environment variables.
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const OEMCatalogApp());
}

final supabase = Supabase.instance.client;

// BLoC instances (singleton, shared across app)
final authBloc = AuthBloc();
final cartBloc = CartBloc();

class OEMCatalogApp extends StatelessWidget {
  const OEMCatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OEM Motorcycle Catalog',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(next: AuthGate()),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription _supabaseAuthSub;

  @override
  void initState() {
    super.initState();
    authBloc.events.add(const AuthCheckRequested());

    // Dengarkan perubahan sesi Supabase (login/logout dari LoginPage yang
    // memanggil Supabase langsung) agar AuthBloc disinkronkan dan UI
    // otomatis berpindah ke katalog / login.
    _supabaseAuthSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      // Sync AuthBloc dengan sesi Supabase terbaru pada setiap perubahan auth.
      authBloc.events.add(const AuthCheckRequested());
    });
  }

  @override
  void dispose() {
    _supabaseAuthSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authBloc.state,
      initialData: authBloc.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? const AuthInitial();
        if (state is AuthInitial || state is AuthLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is AuthAuthenticated) {
          return RoleRouter(key: ValueKey(state.userId));
        }
        return const LoginPage();
      },
    );
  }
}

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  late final Future<String> _role = _fetchRole();

  Future<String> _fetchRole() async {
    try {
      final row = await supabase
          .from('profiles')
          .select('role')
          .eq('id', supabase.auth.currentUser!.id)
          .single();
      return row['role'] as String;
    } catch (_) {
      return 'customer'; // kalau gagal, pakai hak paling rendah
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _role,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final role = snapshot.data ?? 'customer';
        if (role == 'admin') {
          return AdminPartsScreen(role: role);
        }
        return const PartsCatalogScreen();
      },
    );
  }
}

class PartsCatalogScreen extends StatefulWidget {
  const PartsCatalogScreen({super.key});

  @override
  State<PartsCatalogScreen> createState() => _PartsCatalogScreenState();
}

class _PartsCatalogScreenState extends State<PartsCatalogScreen> {
  final _partsStream = supabase.from('parts').stream(primaryKey: ['id']);
  late final Future<String> _username = fetchCurrentUsername();
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Sinkronkan keranjang belanja via BLoC (Event → BLoC → State → UI)
    cartBloc.events.add(const CartLoadRequested());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showProfileSheet(BuildContext context, String username) {
    final email = supabase.auth.currentUser?.email ?? 'user@email.com';
    final initial = username.isNotEmpty
        ? username
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'AP';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Profile Identity
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.red, AppTheme.redDark],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial.isEmpty ? 'AP' : initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username.isEmpty ? 'Pengguna' : username,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.heading,
                            ),
                          ),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.sub,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AppTheme.statusBadge('Member Aktif', type: 'success'),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppTheme.heading),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 8),
                _profileMenuItem(
                  icon: Icons.person_outline,
                  title: 'Data Pribadi',
                  subtitle: 'Nama, email, dan nomor telepon',
                  onTap: () => Navigator.pop(ctx),
                ),
                _profileMenuItem(
                  icon: Icons.home_outlined,
                  title: 'Alamat Pengiriman',
                  subtitle: 'Kelola alamat utama Anda',
                  onTap: () => Navigator.pop(ctx),
                ),
                _profileMenuItem(
                  icon: Icons.shield_outlined,
                  title: 'Keamanan Akun',
                  subtitle: 'Password dan privasi akun',
                  onTap: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tint,
                      foregroundColor: AppTheme.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      cartBloc.events.add(const CartLocalCleared());
                      authBloc.events.add(const AuthLogoutRequested());
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text(
                      'Keluar dari Akun',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.tint,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: AppTheme.red, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppTheme.heading,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 10, color: AppTheme.sub),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFA5A7AA), size: 20),
      onTap: onTap,
    );
  }

  int _getCartQty(CartState? state, String partId) {
    if (state is CartLoaded) {
      for (final item in state.items) {
        if (item.partId == partId) return item.quantity;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 18,
        title: FutureBuilder<String>(
          future: _username,
          builder: (context, snapshot) {
            final name = snapshot.data;
            final displayName = (name != null && name.trim().isNotEmpty) ? name : 'Pengguna';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selamat datang kembali',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.sub,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Halo, $displayName',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.heading,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          FutureBuilder<String>(
            future: _username,
            builder: (context, snapshot) {
              final name = snapshot.data ?? 'AP';
              final initial = name.isNotEmpty
                  ? name
                      .trim()
                      .split(' ')
                      .map((e) => e.isNotEmpty ? e[0] : '')
                      .take(2)
                      .join()
                      .toUpperCase()
                  : 'AP';
              return Padding(
                padding: const EdgeInsets.only(right: 18),
                child: InkWell(
                  onTap: () => _showProfileSheet(context, name),
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 39,
                        height: 39,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppTheme.red, AppTheme.redDark],
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3DB71C1C),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial.isEmpty ? 'AP' : initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppTheme.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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

          final allParts = snapshot.data ?? [];
          final parts = _query.isEmpty
              ? allParts
              : TfIdfSearch(allParts).search(_query);

          return Column(
            children: [
              // Eyebrow, Heading, Search Bar & Section Title
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SPAREPART ORIGINAL',
                      style: TextStyle(
                        color: AppTheme.red,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Siap melaju lebih jauh.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppTheme.heading,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Search bar
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x09000000),
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          const Icon(Icons.search, color: AppTheme.sub, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: 'Cari nama atau part number...',
                                hintStyle: TextStyle(fontSize: 12, color: AppTheme.sub),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                fillColor: Colors.transparent,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (v) =>
                                  setState(() => _query = v.trim().toLowerCase()),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: AppTheme.sub),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Section Heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Semua Produk',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.heading,
                          ),
                        ),
                        Text(
                          '${parts.length} barang',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.sub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Product Grid
              Expanded(
                child: allParts.isEmpty
                    ? const Center(
                        child: Text(
                          'No spare parts found in database.',
                          style: TextStyle(color: AppTheme.sub),
                        ),
                      )
                    : parts.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada hasil untuk pencarian ini.',
                              style: TextStyle(color: AppTheme.sub),
                            ),
                          )
                        : StreamBuilder<CartState>(
                            stream: cartBloc.state,
                            initialData: cartBloc.currentState,
                            builder: (context, cartSnapshot) {
                              final cartState = cartSnapshot.data;

                              return GridView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.58,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: parts.length,
                                itemBuilder: (context, index) {
                                  final part = parts[index];
                                  final partId = part['id'].toString();
                                  final stock = (part['stock'] as num? ?? 0).toInt();
                                  final isSoldOut = stock <= 0;
                                  final inCartQty = _getCartQty(cartState, partId);
                                  final category = (part['category'] ?? 'SPAREPART')
                                      .toString()
                                      .toUpperCase();

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.border),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x09000000),
                                          blurRadius: 12,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Image with Soldout badge
                                        Stack(
                                          children: [
                                            Container(
                                              height: 130,
                                              width: double.infinity,
                                              color: const Color(0xFFEEEEEE),
                                              child: part['image_url'] != null
                                                  ? Image.network(
                                                      part['image_url'] as String,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, _, _) =>
                                                              const Icon(
                                                        Icons.two_wheeler,
                                                        size: 44,
                                                        color: AppTheme.red,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.two_wheeler,
                                                      size: 44,
                                                      color: AppTheme.red,
                                                    ),
                                            ),
                                            if (isSoldOut)
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xD9222222),
                                                    borderRadius:
                                                        BorderRadius.circular(16),
                                                  ),
                                                  child: const Text(
                                                    'Habis',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),

                                        // Product Details
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(10.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Category Tag
                                                Text(
                                                  category,
                                                  style: const TextStyle(
                                                    fontSize: 8,
                                                    color: AppTheme.red,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.7,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                // Name
                                                Text(
                                                  part['name'] ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                    color: AppTheme.heading,
                                                    height: 1.25,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                // Part Number code badge
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF3F3F2),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '${part['part_number']}',
                                                    style: const TextStyle(
                                                      fontFamily: 'RobotoMono',
                                                      color: AppTheme.sub,
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                // Price
                                                Text(
                                                  AppTheme.formatRupiah(
                                                    part['price'] as num? ?? 0,
                                                  ),
                                                  style: const TextStyle(
                                                    color: AppTheme.green,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                // Stock Text
                                                Text(
                                                  isSoldOut
                                                      ? 'Stok habis'
                                                      : 'Stok $stock',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: isSoldOut
                                                        ? AppTheme.red
                                                        : AppTheme.sub,
                                                    fontWeight: isSoldOut
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                // Add button
                                                SizedBox(
                                                  width: double.infinity,
                                                  height: 34,
                                                  child: ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: isSoldOut
                                                          ? const Color(0xFFE6E6E6)
                                                          : inCartQty > 0
                                                              ? AppTheme.tint
                                                              : AppTheme.red,
                                                      foregroundColor: isSoldOut
                                                          ? const Color(0xFF9B9B9B)
                                                          : inCartQty > 0
                                                              ? AppTheme.red
                                                              : Colors.white,
                                                      elevation: 0,
                                                      padding: EdgeInsets.zero,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                8),
                                                      ),
                                                    ),
                                                    onPressed: isSoldOut
                                                        ? null
                                                        : () {
                                                            cartBloc.events.add(
                                                              CartItemAdded(
                                                                partId: partId,
                                                                name: (part['name'] ?? '')
                                                                    .toString(),
                                                                price: (part['price'] as num)
                                                                    .toDouble(),
                                                                stock: stock,
                                                              ),
                                                            );
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).hideCurrentSnackBar();
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  '${part['name']} ditambahkan ke keranjang',
                                                                ),
                                                                duration:
                                                                    const Duration(
                                                                  seconds: 1,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.center,
                                                      children: [
                                                        if (!isSoldOut && inCartQty == 0) ...[
                                                          const Icon(
                                                            Icons.add,
                                                            size: 15,
                                                          ),
                                                          const SizedBox(width: 3),
                                                        ],
                                                        Text(
                                                          isSoldOut
                                                              ? 'Habis'
                                                              : inCartQty > 0
                                                                  ? '$inCartQty di keranjang'
                                                                  : 'Tambah',
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildFloatingBottomNav(context),
    );
  }

  Widget _buildFloatingBottomNav(BuildContext context) {
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
          BoxShadow(
            color: Color(0x0F191919),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Katalog (Active Tab)
          _buildNavItem(
            icon: Icons.home_rounded,
            label: 'Katalog',
            isActive: true,
            onTap: () {},
          ),
          // Riwayat
          _buildNavItem(
            icon: Icons.receipt_long_rounded,
            label: 'Riwayat',
            isActive: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
            ),
          ),
          // Keranjang with Badge
          StreamBuilder<CartState>(
            stream: cartBloc.state,
            initialData: cartBloc.currentState,
            builder: (context, snapshot) {
              final cartState = snapshot.data;
              final count = cartState is CartLoaded ? cartState.totalCount : 0;

              return _buildNavItem(
                icon: Icons.shopping_cart_rounded,
                label: 'Keranjang',
                isActive: false,
                badgeCount: count,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    int badgeCount = 0,
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
            Stack(
              clipBehavior: Clip.none,
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
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x3DB71C1C),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
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
