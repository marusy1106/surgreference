import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import '../core/api/secure_token_store.dart';
import '../core/api/token_store.dart';
import '../core/config.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/models.dart';
import '../features/learning/data/api_learning_repository.dart';
import '../features/learning/data/learning_repository.dart';

/// Подменяется в тестах на [MemoryTokenStore].
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: AppConfig.apiBaseUrl, store: ref.watch(tokenStoreProvider)),
);

final deviceInfoProvider = Provider<DeviceInfo>(
  (ref) => DeviceInfo(
    platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    appVersion: AppConfig.appVersion,
  ),
);

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider), ref.watch(deviceInfoProvider)),
);

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => ApiLearningRepository(ref.watch(apiClientProvider)),
);

/// Никнейм вошедшего пользователя — для приветствия, рейтинга и профиля.
final nicknameProvider = Provider<String>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is SignedIn ? auth.user.displayName : '';
});

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// Тема «Системная» по умолчанию, выбор запоминается на устройстве (docs/08-design.md, 8.4).
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    SharedPreferences.getInstance().then((prefs) {
      final saved = ThemeMode.values.asNameMap()[prefs.getString(_key)];
      if (saved != null) state = saved;
    }).ignore();
    return ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await (await SharedPreferences.getInstance()).setString(_key, mode.name);
  }
}
