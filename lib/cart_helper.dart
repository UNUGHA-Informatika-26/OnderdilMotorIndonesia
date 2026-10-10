import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartItem {
  final String partId;
  final String name;
  final double price;
  final int stock;
  int quantity;

  CartItem({
    required this.partId,
    required this.name,
    required this.price,
    required this.stock,
    this.quantity = 1,
  });

  double get subtotal => price * quantity;
}

/// Keranjang belanja yang tersimpan permanen di Supabase database (tabel `cart_items`).
/// Data tetap ada meskipun aplikasi ditutup, ganti device, atau reload.
class CartModel extends ChangeNotifier {
  CartModel._internal();
  static final CartModel instance = CartModel._internal();

  static const int maxQuantityPerItem = 99;

  final Map<String, CartItem> _items = {};
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<CartItem> get items => _items.values.toList();
  bool get isEmpty => _items.isEmpty;
  int get totalCount => _items.values.fold(0, (sum, i) => sum + i.quantity);
  double get totalPrice => _items.values.fold(0.0, (sum, i) => sum + i.subtotal);

  int _capFor(int stock) =>
      stock < maxQuantityPerItem ? stock : maxQuantityPerItem;

  SupabaseClient get _db => Supabase.instance.client;
  String? get _currentUserId => _db.auth.currentUser?.id;

  /// Memuat keranjang user dari database Supabase
  Future<void> loadCartFromDatabase() async {
    final uid = _currentUserId;
    if (uid == null) {
      _items.clear();
      notifyListeners();
      return;
    }

    // Kosongkan dulu supaya isi keranjang akun sebelumnya tidak ikut
    // terbawa kalau pengambilan data di bawah gagal (mis. jaringan putus).
    _items.clear();
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _db
          .from('cart_items')
          .select('quantity, parts(id, name, price, stock)')
          .eq('user_id', uid);

      _items.clear();
      for (final row in data as List) {
        final part = row['parts'] as Map<String, dynamic>?;
        if (part != null) {
          final pId = part['id'].toString();
          final stock = (part['stock'] as num? ?? 0).toInt();
          final price = (part['price'] as num? ?? 0).toDouble();
          final name = (part['name'] ?? '').toString();
          final qty = (row['quantity'] as num? ?? 1).toInt();

          _items[pId] = CartItem(
            partId: pId,
            name: name,
            price: price,
            stock: stock,
            quantity: qty > _capFor(stock) ? _capFor(stock) : qty,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loadCartFromDatabase: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tambah item ke keranjang dan simpan ke database
  Future<void> add({
    required String partId,
    required String name,
    required double price,
    required int stock,
  }) async {
    final existing = _items[partId];
    final cap = _capFor(stock);
    int newQuantity = 1;

    if (existing != null) {
      if (existing.quantity < cap) {
        newQuantity = existing.quantity + 1;
        existing.quantity = newQuantity;
      } else {
        return;
      }
    } else if (cap > 0) {
      newQuantity = 1;
      _items[partId] = CartItem(
        partId: partId,
        name: name,
        price: price,
        stock: stock,
        quantity: newQuantity,
      );
    } else {
      return;
    }
    notifyListeners();

    final uid = _currentUserId;
    if (uid != null) {
      try {
        await _db.from('cart_items').upsert({
          'user_id': uid,
          'part_id': partId,
          'quantity': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,part_id');
      } catch (e) {
        debugPrint('Error sync add cart: $e');
      }
    }
  }

  /// Naikkan kuantitas 1 item
  Future<void> increment(String partId) async {
    final item = _items[partId];
    if (item != null && item.quantity < _capFor(item.stock)) {
      item.quantity++;
      notifyListeners();

      final uid = _currentUserId;
      if (uid != null) {
        try {
          await _db.from('cart_items').update({
            'quantity': item.quantity,
            'updated_at': DateTime.now().toIso8601String(),
          }).match({'user_id': uid, 'part_id': partId});
        } catch (e) {
          debugPrint('Error sync increment cart: $e');
        }
      }
    }
  }

  /// Kurangi kuantitas atau hapus jika 1
  Future<void> decrement(String partId) async {
    final item = _items[partId];
    if (item == null) return;

    final uid = _currentUserId;
    if (item.quantity <= 1) {
      _items.remove(partId);
      notifyListeners();
      if (uid != null) {
        try {
          await _db.from('cart_items').delete().match({
            'user_id': uid,
            'part_id': partId,
          });
        } catch (e) {
          debugPrint('Error sync delete cart: $e');
        }
      }
    } else {
      item.quantity--;
      notifyListeners();
      if (uid != null) {
        try {
          await _db.from('cart_items').update({
            'quantity': item.quantity,
            'updated_at': DateTime.now().toIso8601String(),
          }).match({'user_id': uid, 'part_id': partId});
        } catch (e) {
          debugPrint('Error sync decrement cart: $e');
        }
      }
    }
  }

  /// Hapus 1 item dari keranjang
  Future<void> remove(String partId) async {
    _items.remove(partId);
    notifyListeners();

    final uid = _currentUserId;
    if (uid != null) {
      try {
        await _db.from('cart_items').delete().match({
          'user_id': uid,
          'part_id': partId,
        });
      } catch (e) {
        debugPrint('Error sync remove cart: $e');
      }
    }
  }

  /// Kosongkan keranjang belanja (juga menghapus datanya di database).
  /// Dipakai setelah checkout berhasil.
  Future<void> clear() async {
    _items.clear();
    notifyListeners();

    final uid = _currentUserId;
    if (uid != null) {
      try {
        await _db.from('cart_items').delete().eq('user_id', uid);
      } catch (e) {
        debugPrint('Error sync clear cart: $e');
      }
    }
  }

  /// Kosongkan tampilan di memori SAJA (data di database tetap ada).
  /// Dipakai saat logout, supaya keranjang akun ini tidak terlihat oleh
  /// akun berikutnya, tapi tetap muncul lagi saat akun ini login kembali.
  void clearLocal() {
    _items.clear();
    notifyListeners();
  }
}