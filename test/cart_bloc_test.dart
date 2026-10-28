// Unit test — CartBloc (lib/bloc/cart_bloc.dart)
// Test case: U-CB-01 s/d U-CB-12
//
// Menguji pola BLoC (Event → StreamController → State → UI) untuk
// keranjang belanja. CartBloc mendelegasikan ke CartModel (data layer)
// yang sudah diuji terpisah di cart_model_test.dart.
//
// Setup: Supabase diinisialisasi dengan URL dummy sehingga currentUser == null.
// Semua cabang sync-DB otomatis ter-skip (uid null), jadi yang diuji adalah
// alur event→state secara murni — tanpa jaringan, cepat, dan deterministik.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:oem_sparepart_catalog/bloc/bloc.dart';
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

  late CartBloc bloc;

  setUp(() {
    CartModel.instance.clearLocal(); // mulai dari keranjang kosong
    bloc = CartBloc();
  });

  tearDown(() => bloc.dispose());

  // ─── Helper ───────────────────────────────────────────────────────────

  /// Kirim event lalu tunggu state terbaru yang di-emit.
  Future<CartState> send(CartEvent event) async {
    final future = bloc.state.first; // ambil state berikutnya
    bloc.events.add(event);
    return future;
  }

  // ─── State class & property ───────────────────────────────────────────

  group('CartState — properti class', () {
    test('U-CB-01: CartInitial adalah state awal', () {
      expect(bloc.currentState, isA<CartInitial>());
    });

    test('U-CB-02: CartLoaded.subtotal mengembalikan totalPrice', () {
      final loaded = CartLoaded(
        items: [],
        totalPrice: 250000,
        totalCount: 3,
        isEmpty: false,
      );
      expect(loaded.subtotal, 250000);
    });

    test('U-CB-03: CartError menyimpan pesan error', () {
      final error = CartError('Gagal memuat');
      expect(error.message, 'Gagal memuat');
    });
  });

  // ─── Event class ──────────────────────────────────────────────────────

  group('CartEvent — properti class', () {
    test('U-CB-04: CartItemAdded menyimpan atribut part', () {
      const event = CartItemAdded(
        partId: 'p1',
        name: 'Busi NGK',
        price: 35000,
        stock: 10,
      );
      expect(event.partId, 'p1');
      expect(event.name, 'Busi NGK');
      expect(event.price, 35000);
      expect(event.stock, 10);
    });

    test('U-CB-05: CartItemIncremented & Decremented menyimpan partId', () {
      const inc = CartItemIncremented('p1');
      const dec = CartItemDecremented('p1');
      expect(inc.partId, 'p1');
      expect(dec.partId, 'p1');
    });

    test('U-CB-06: CartItemRemoved menyimpan partId', () {
      const removed = CartItemRemoved('p1');
      expect(removed.partId, 'p1');
    });
  });

  // ─── CartBloc alur event → state ─────────────────────────────────────

  group('CartBloc — alur event → state', () {
    test('U-CB-07: CartItemAdded menghasilkan CartLoaded dengan 1 item',
        () async {
      final state = await send(const CartItemAdded(
        partId: 'p1',
        name: 'Busi NGK',
        price: 35000,
        stock: 10,
      ));

      expect(state, isA<CartLoaded>());
      final loaded = state as CartLoaded;
      expect(loaded.items.length, 1);
      expect(loaded.items.first.partId, 'p1');
      expect(loaded.totalCount, 1);
      expect(loaded.totalPrice, 35000);
      expect(loaded.isEmpty, isFalse);
    });

    test('U-CB-08: CartItemIncremented menambah qty menjadi 2', () async {
      // Tambah item dulu
      await send(const CartItemAdded(
        partId: 'p1',
        name: 'Busi NGK',
        price: 35000,
        stock: 10,
      ));

      final state = await send(const CartItemIncremented('p1'));
      final loaded = state as CartLoaded;
      expect(loaded.items.first.quantity, 2);
      expect(loaded.totalPrice, 70000);
    });

    test('U-CB-09: CartItemDecremented dari qty 2 menjadi 1', () async {
      await send(const CartItemAdded(
        partId: 'p1',
        name: 'Busi NGK',
        price: 35000,
        stock: 10,
      ));
      await send(const CartItemIncremented('p1'));

      final state = await send(const CartItemDecremented('p1'));
      final loaded = state as CartLoaded;
      expect(loaded.items.first.quantity, 1);
      expect(loaded.totalPrice, 35000);
    });

    test('U-CB-10: CartItemDecremented dari qty 1 menghapus item', () async {
      await send(const CartItemAdded(
        partId: 'p1',
        name: 'Busi NGK',
        price: 35000,
        stock: 10,
      ));

      final state = await send(const CartItemDecremented('p1'));
      final loaded = state as CartLoaded;
      expect(loaded.items, isEmpty);
      expect(loaded.isEmpty, isTrue);
    });

    test('U-CB-11: CartItemRemoved menghapus item langsung', () async {
      await send(const CartItemAdded(
        partId: 'p1',
        name: 'Busi NGK',
        price: 35000,
        stock: 10,
      ));
      await send(const CartItemAdded(
        partId: 'p2',
        name: 'Kampas Rem',
        price: 50000,
        stock: 5,
      ));

      final state = await send(const CartItemRemoved('p1'));
      final loaded = state as CartLoaded;
      expect(loaded.items.length, 1);
      expect(loaded.items.first.partId, 'p2');
      expect(loaded.totalPrice, 50000);
    });

    test('U-CB-12: CartLocalCleared mengosongkan seluruh keranjang', () async {
      await send(const CartItemAdded(
        partId: 'p1',
        name: 'Busi NGK',
        price: 35000,
        stock: 10,
      ));
      await send(const CartItemAdded(
        partId: 'p2',
        name: 'Kampas Rem',
        price: 50000,
        stock: 5,
      ));

      final state = await send(const CartLocalCleared());
      final loaded = state as CartLoaded;
      expect(loaded.items, isEmpty);
      expect(loaded.isEmpty, isTrue);
      expect(loaded.totalCount, 0);
      expect(loaded.totalPrice, 0);
    });
  });
}
