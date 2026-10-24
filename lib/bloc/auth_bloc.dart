import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'auth_event.dart';
import 'auth_state.dart';

/// AuthBloc — menangani state autentikasi.
///
/// Pola BLoC: AuthEvent → AuthBloc (StreamController) → AuthState → UI (StreamBuilder)
class AuthBloc {
  AuthBloc() {
    _eventController.stream.listen(_mapEventToState);
  }

  final SupabaseClient _db = Supabase.instance.client;

  final _eventController = StreamController<AuthEvent>.broadcast();
  StreamSink<AuthEvent> get events => _eventController.sink;

  final _stateController = StreamController<AuthState>.broadcast();
  Stream<AuthState> get state => _stateController.stream;

  AuthState _currentState = const AuthInitial();
  AuthState get currentState => _currentState;

  void _emit(AuthState state) {
    _currentState = state;
    _stateController.add(state);
  }

  Future<void> _mapEventToState(AuthEvent event) async {
    if (event is AuthCheckRequested) {
      await _onCheck();
    } else if (event is AuthLoginRequested) {
      await _onLogin(event);
    } else if (event is AuthRegisterRequested) {
      await _onRegister(event);
    } else if (event is AuthLogoutRequested) {
      await _onLogout();
    }
  }

  Future<void> _onCheck() async {
    final session = _db.auth.currentSession;
    if (session == null) {
      _emit(AuthUnauthenticated()); // ❌ Hapus 'const'
      return;
    }
    final userId = session.user.id;
    final meta = session.user.userMetadata ?? {};
    final username = meta['username'] as String? ?? '';
    final role = await _fetchRole(userId);
    _emit(AuthAuthenticated(userId: userId, username: username, role: role));
  }

  Future<void> _onLogin(AuthLoginRequested event) async {
    _emit(AuthLoading()); // ❌ Hapus 'const'
    try {
      String email = event.identifier;
      if (!email.contains('@')) {
        final res = await _db.rpc('get_email_by_username',
            params: {'p_username': email});
        email = res as String;
      }
      final response = await _db.auth.signInWithPassword(
        email: email,
        password: event.password,
      );
      if (response.user == null) {
        _emit(AuthError('Login gagal')); // ❌ Hapus 'const'
        return;
      }
      final userId = response.user!.id;
      final meta = response.user!.userMetadata ?? {};
      final username = meta['username'] as String? ?? event.identifier;
      final role = await _fetchRole(userId);
      _emit(AuthAuthenticated(userId: userId, username: username, role: role));
    } on AuthException catch (e) {
      _emit(AuthError(e.message));
    } catch (e) {
      _emit(AuthError('Terjadi kesalahan: $e'));
    }
  }

  Future<void> _onRegister(AuthRegisterRequested event) async {
    _emit(AuthLoading()); // ❌ Hapus 'const'
    try {
      await _db.auth.signUp(
        email: event.email,
        password: event.password,
        data: {'username': event.username},
      );
      _emit(AuthUnauthenticated()); // ❌ Hapus 'const'
    } on AuthException catch (e) {
      _emit(AuthError(e.message));
    } catch (e) {
      _emit(AuthError('Terjadi kesalahan: $e'));
    }
  }

  Future<void> _onLogout() async {
    await _db.auth.signOut();
    _emit(AuthUnauthenticated()); // ❌ Hapus 'const'
  }

  Future<String> _fetchRole(String userId) async {
    try {
      final data = await _db
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return data?['role'] as String? ?? 'customer';
    } catch (_) {
      return 'customer';
    }
  }

  void dispose() {
    _eventController.close();
    _stateController.close();
  }
}