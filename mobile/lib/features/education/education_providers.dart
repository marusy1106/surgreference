import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import 'data/education_api.dart';
import 'data/education_models.dart';

final educationApiProvider = Provider<EducationApi>((ref) => EducationApi(ref.watch(apiClientProvider)));

final educationProvider = FutureProvider.autoDispose<EducationProfile>(
  (ref) => ref.watch(educationApiProvider).profile(),
);

final specialtiesProvider = FutureProvider.autoDispose.family<List<SpecialtyOption>, String>(
  (ref, level) => ref.watch(educationApiProvider).specialties(level),
);

final educationPromptDismissedProvider = NotifierProvider<EducationPromptController, bool>(
  EducationPromptController.new,
);

/// Профиль можно пропустить (docs/01-mvp.md): карточка на главной закрывается навсегда на этом устройстве.
class EducationPromptController extends Notifier<bool> {
  static const _key = 'education_prompt_dismissed';

  @override
  bool build() {
    SharedPreferences.getInstance().then((prefs) {
      if (prefs.getBool(_key) ?? false) state = true;
    }).ignore();
    return false;
  }

  Future<void> dismiss() async {
    state = true;
    await (await SharedPreferences.getInstance()).setBool(_key, true);
  }
}
