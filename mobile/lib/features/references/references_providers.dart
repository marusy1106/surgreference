import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'data/references_api.dart';
import 'data/references_models.dart';

final referencesApiProvider = Provider<ReferencesApi>((ref) => ReferencesApi(ref.watch(apiClientProvider)));

final icdSearchProvider = FutureProvider.autoDispose.family<List<IcdCode>, String>(
  (ref, query) => ref.watch(referencesApiProvider).searchIcd(query),
);

final icdCodeProvider = FutureProvider.autoDispose.family<IcdCodeDetail, String>(
  (ref, code) => ref.watch(referencesApiProvider).icdCode(code),
);

final guidelineSearchProvider = FutureProvider.autoDispose
    .family<List<GuidelineBrief>, ({String query, GuidelineStatus? status})>(
      (ref, args) => ref.watch(referencesApiProvider).searchGuidelines(args.query, args.status),
    );

final guidelineProvider = FutureProvider.autoDispose.family<GuidelineDetail, int>(
  (ref, id) => ref.watch(referencesApiProvider).guideline(id),
);
