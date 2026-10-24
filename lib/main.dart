import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'auth_pages.dart';
import 'admin_page.dart';
import 'profile_helper.dart';
import 'cart_helper.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import 'search_helper.dart';
import 'splash_screen.dart';
import 'bloc/bloc.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
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
  @override
  void initState() {
    super.initState();
    authBloc.events.add(const AuthCheckRequested());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: _username,
          builder: (context, snapshot) {
            final name = snapshot.data;
            return Text(
              name == null || name.isEmpty
                  ? 'OEM Parts Catalog'
                  : 'Halo, $name',
            );
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Riwayat Pesanan',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
            ),
          ),
          StreamBuilder<CartState>(
            stream: cartBloc.state,
            initialData: cartBloc.currentState,
            builder: (context, snapshot) {
              final cartState = snapshot.data;
              final count = cartState is CartLoaded ? cartState.totalCount : 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
  icon: const Icon(Icons.logout),
  onPressed: () {
    cartBloc.events.add(const CartLocalCleared());
    authBloc.events.add(const AuthLogoutRequested());
  },
),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama atau part number...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
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

                if (allParts.isEmpty) {
                  return const Center(
                    child: Text('No spare parts found in database.'),
                  );
                }
                if (parts.isEmpty) {
                  return const Center(
                    child: Text('Tidak ada hasil untuk pencarian ini.'),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 5,
                  ),
                  itemCount: parts.length,
                  itemBuilder: (context, index) {
                    final part = parts[index];
                    return Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: part['image_url'] != null
                                    ? Image.network(
                                        part['image_url'] as String,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            const Icon(
                                              Icons.build_circle_outlined,
                                              size: 48,
                                              color: Colors.blueAccent,
                                            ),
                                      )
                                    : const Icon(
                                        Icons.build_circle_outlined,
                                        size: 48,
                                        color: Colors.blueAccent,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              part['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'PN: ${part['part_number']}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Rp ${(part['price'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Stock: ${part['stock']}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              height: 32,
                              child: FilledButton.tonalIcon(
                                onPressed: (part['stock'] as num? ?? 0) <= 0
                                    ? null
                                    : () {
                                        CartModel.instance.add(
                                          partId: part['id'].toString(),
                                          name: (part['name'] ?? '').toString(),
                                          price: (part['price'] as num)
                                              .toDouble(),
                                          stock: (part['stock'] as num).toInt(),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${part['name']} ditambahkan ke keranjang',
                                            ),
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                          ),
                                        );
                                      },
                                icon: const Icon(
                                  Icons.add_shopping_cart,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Tambah',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
