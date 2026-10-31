import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_error.dart';
import '../data/models.dart';

sealed class AuthState {
  const AuthState();
}

/// Запуск: пробуем восстановить сессию по сохранённому refresh-токену.
class AuthRestoring extends AuthState {
  const AuthRestoring();
}

class SignedOut extends AuthState {
  const SignedOut({this.reason});

  /// Почему вышли без участия пользователя (сессия завершена на сервере).
  final String? reason;
}

/// Зарегистрировались или вошли без подтверждённого email: ждём код из письма.
class AwaitingVerification extends AuthState {
  const AwaitingVerification(this.email);

  final String email;
}

class SignedIn extends AuthState {
  const SignedIn(this.user);

  final User user;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Состояние входа для роутера и экранов. Методы бросают [ApiException] — формы показывают её сами.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final client = ref.watch(apiClientProvider);
    client.onSessionExpired = () => state = const SignedOut(reason: 'Сессия завершена. Войдите снова.');
    Future.microtask(_restore);
    return const AuthRestoring();
  }

  Future<void> _restore() async {
    try {
      final user = await ref.read(authApiProvider).restore();
      state = user == null ? const SignedOut() : _signedIn(user);
    } on ApiException {
      // Нет сети при запуске: без сервера войти нельзя, токен остаётся для следующей попытки.
      state = const SignedOut(reason: 'Нет связи с сервером. Проверьте интернет и войдите снова.');
    }
  }

  AuthState _signedIn(User user) => user.emailVerified ? SignedIn(user) : AwaitingVerification(user.email);

  Future<Map<String, String>> legalVersions() => ref.read(authApiProvider).legalVersions();

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required Map<String, String> consents,
  }) async {
    await ref
        .read(authApiProvider)
        .register(email: email, password: password, displayName: displayName, consents: consents);
    state = AwaitingVerification(email.trim());
  }

  Future<void> verifyEmail(String code) async {
    final pending = state;
    if (pending is! AwaitingVerification) return;
    state = SignedIn(await ref.read(authApiProvider).verifyEmail(pending.email, code));
  }

  Future<void> resendCode() async {
    final pending = state;
    if (pending is AwaitingVerification) await ref.read(authApiProvider).resendCode(pending.email);
  }

  Future<void> login(String email, String password) async {
    final api = ref.read(authApiProvider);
    final user = await api.login(email, password);
    if (!user.emailVerified) {
      // Без подтверждённого адреса в приложение не пускаем: сессию закрываем, высылаем новый код.
      await api.logout();
      await api.resendCode(user.email);
    }
    state = _signedIn(user);
  }

  /// Вернуться к входу с экрана кода (другой адрес, опечатка).
  void cancelVerification() => state = const SignedOut();

  void updateUser(User user) => state = SignedIn(user);

  Future<void> logout() async {
    await ref.read(authApiProvider).logout();
    state = const SignedOut();
  }

  Future<void> deleteAccount(String code) async {
    await ref.read(authApiProvider).deleteAccount(code);
    state = const SignedOut(reason: 'Аккаунт удалён.');
  }
}
