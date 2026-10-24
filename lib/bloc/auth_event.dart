abstract class AuthEvent {
  const AuthEvent();
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.identifier, required this.password});
  final String identifier;
  final String password;
}

class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.username,
  });
  final String email;
  final String password;
  final String username;
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}