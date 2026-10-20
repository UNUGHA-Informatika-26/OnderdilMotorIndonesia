// Unit test — Keranjang belanja (lib/cart_helper.dart)
// Test case: docs/pengujian/rencana-pengujian.md bagian 6.2 (U-C-01 s/d U-C-15)
//
// Setup: Supabase diinisialisasi dengan URL dummy sehingga currentUser == null.
// Semua cabang sync-DB otomatis ter-skip (uid null), jadi yang diuji adalah
// logika lokal keranjang secara murni — tanpa jaringan, cepat, dan deterministik.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oem_sparepart_catalog/cart_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'anon-key-palsu-untuk-test',
    );
  });

  final cart = CartModel.instance;

  // Pastikan tiap test mulai dari keranjang kosong.
  setUp(() => cart.clearLocal());

  Future<void> add(String id, {double price = 100, int stock = 5}) =>
      cart.add(partId: id, name: 'Part $id', price: price, stock: stock);

  group('CartItem', () {
    test('U-C-01: subtotal = price x quantity', () {
      final item = CartItem(
          partId: 'p', name: 'N', price: 15000, stock: 5, quantity: 3);
      expect(item.subtotal, 45000);
    });
  });

  group('CartModel — logika lokal', () {
    test('U-C-02: item baru masuk dengan quantity 1', () async {
      await add('p1');
      expect(cart.items.single.quantity, 1);
      expect(cart.totalCount, 1);
    });

    test('U-C-03: part dengan stok 0 tidak bisa ditambahkan', () async {
      await add('p0', stock: 0);
      expect(cart.isEmpty, isTrue);
    });

    test('U-C-04: menambah part sama menaikkan quantity & total', () async {
      await add('p1', price: 100);
      await add('p1', price: 100);
      expect(cart.items.single.quantity, 2);
      expect(cart.totalPrice, 200);
    });

    test('U-C-05: quantity dibatasi stok (add 6x, stok 3)', () async {
      for (var i = 0; i < 6; i++) {
        await add('p2', stock: 3);
      }
      expect(cart.items.single.quantity, 3);
    });

    test('U-C-06: quantity dibatasi 99 walau stok 500', () async {
      for (var i = 0; i < 100; i++) {
        await add('p3', stock: 500);
      }
      expect(cart.items.single.quantity, CartModel.maxQuantityPerItem);
    });

    test('U-C-07: increment di batas maksimum tidak menambah', () async {
      for (var i = 0; i < 99; i++) {
        await add('p3', stock: 500);
      }
      await cart.increment('p3');
      expect(cart.items.single.quantity, 99);
    });

    test('U-C-08: decrement di quantity > 1 menurunkan quantity', () async {
      await add('p1');
      await add('p1');
      await add('p1');
      await cart.decrement('p1');
      expect(cart.items.single.quantity, 2);
    });

    test('U-C-09: decrement di quantity 1 menghapus item', () async {
      await add('p1');
      await cart.decrement('p1');
      expect(cart.isEmpty, isTrue);
    });

    test('U-C-10: remove menghapus item yang dipilih saja', () async {
      await add('p1');
      await add('p2');
      await cart.remove('p1');
      expect(cart.items.single.partId, 'p2');
    });

    test('U-C-11: clear mengosongkan seluruh keranjang', () async {
      await add('p1');
      await add('p2');
      await cart.clear();
      expect(cart.isEmpty, isTrue);
      expect(cart.totalCount, 0);
    });

    test('U-C-13: totalPrice menjumlahkan subtotal semua item', () async {
      await add('p1', price: 100); // 2x → 200
      await add('p1', price: 100);
      await add('p2', price: 50); // 1x → 50
      expect(cart.totalPrice, 250);
    });

    test('U-C-14: setiap mutasi memanggil notifyListeners', () async {
      var notified = 0;
      void listener() => notified++;
      cart.addListener(listener);
      await add('p1');
      await cart.decrement('p1');
      cart.removeListener(listener);
      expect(notified, greaterThanOrEqualTo(2));
    });

    test('U-C-15: loadCartFromDatabase tanpa login aman & mengosongkan',
        () async {
      await add('p1'); // isi dulu, pastikan bersih setelah load
      await cart.loadCartFromDatabase();
      expect(cart.isEmpty, isTrue);
      expect(cart.isLoading, isFalse);
    });
  });
}
