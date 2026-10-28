// Unit test — AuthBloc Events & States (lib/bloc/auth_bloc.dart)
// Test case: U-AB-01 s/d U-AB-10
//
// AuthBloc bergantung langsung pada Supabase Auth (signInWithPassword, signUp,
// signOut, RPC). Karena test ini berjalan tanpa backend/mock server, kita
// menguji:
//  1. Properti & konstruktor semua AuthEvent.
//  2. Properti & konstruktor semua AuthState.
//  3. State awal AuthBloc (AuthInitial).
//  4. Alur event yang bisa dijalankan offline (AuthCheckRequested → user null
//     → AuthUnauthenticated, AuthLogoutRequested → AuthUnauthenticated).
//
// Untuk login/register yang membutuhkan koneksi Supabase, cukup diverifikasi
// secara manual atau integration test.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:oem_sparepart_catalog/bloc/bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'anon-key-palsu-untuk-test',
    );
  });

  // ─── AuthEvent ────────────────────────────────────────────────────────

  group('AuthEvent — properti class', () {
    test('U-AB-01: AuthCheckRequested bisa dikonstruksi const', () {
      const event = AuthCheckRequested();
      expect(event, isA<AuthEvent>());
    });

    test('U-AB-02: AuthLoginRequested menyimpan identifier & password', () {
      const event = AuthLoginRequested(
        identifier: 'user123',
        password: 'rahasia',
      );
      expect(event.identifier, 'user123');
      expect(event.password, 'rahasia');
    });

    test('U-AB-03: AuthRegisterRequested menyimpan email, password, username',
        () {
      const event = AuthRegisterRequested(
        email: 'user@mail.com',
        password: 'rahasia',
        username: 'user123',
      );
      expect(event.email, 'user@mail.com');
      expect(event.password, 'rahasia');
      expect(event.username, 'user123');
    });

    test('U-AB-04: AuthLogoutRequested bisa dikonstruksi const', () {
      const event = AuthLogoutRequested();
      expect(event, isA<AuthEvent>());
    });
  });

  // ─── AuthState ────────────────────────────────────────────────────────

  group('AuthState — properti class', () {
    test('U-AB-05: AuthInitial adalah subclass AuthState', () {
      const state = AuthInitial();
      expect(state, isA<AuthState>());
    });

    test('U-AB-06: AuthLoading adalah subclass AuthState', () {
      const state = AuthLoading();
      expect(state, isA<AuthState>());
    });

    test('U-AB-07: AuthAuthenticated menyimpan userId, username, role', () {
      const state = AuthAuthenticated(
        userId: 'uid-abc-123',
        username: 'toko_jaya',
        role: 'admin',
      );
      expect(state.userId, 'uid-abc-123');
      expect(state.username, 'toko_jaya');
      expect(state.role, 'admin');
    });

    test('U-AB-08: AuthError menyimpan pesan error', () {
      const state = AuthError('Email atau password salah');
      expect(state.message, 'Email atau password salah');
    });
  });

  // ─── AuthBloc alur event → state ─────────────────────────────────────

  group('AuthBloc — alur event → state', () {
    late AuthBloc bloc;

    setUp(() {
      bloc = AuthBloc();
    });

    tearDown(() => bloc.dispose());

    test('U-AB-09: state awal adalah AuthInitial', () {
      expect(bloc.currentState, isA<AuthInitial>());
    });

    test(
        'U-AB-10: AuthCheckRequested tanpa session → emit AuthUnauthenticated',
        () async {
      // Tidak ada user yang login di mock Supabase → seharusnya Unauthenticated
      final future = bloc.state.first;
      bloc.events.add(const AuthCheckRequested());
      final state = await future;

      expect(state, isA<AuthUnauthenticated>());
      expect(bloc.currentState, isA<AuthUnauthenticated>());
    });
  });
}
