import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/ui/ui.dart';
import '../data/education_models.dart';
import '../education_providers.dart';

/// Результат поиска: выбранный вуз из справочника или название из заявки «Моего вуза нет».
typedef UniversityPick = ({UniversityOption? university, String? requested});

class UniversitySearchPage extends ConsumerStatefulWidget {
  const UniversitySearchPage({super.key});

  @override
  ConsumerState<UniversitySearchPage> createState() => _UniversitySearchPageState();
}

class _UniversitySearchPageState extends ConsumerState<UniversitySearchPage> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<UniversityOption>? _results;
  ApiException? _error;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(text));
  }

  Future<void> _search(String text) async {
    // Ответ на устаревший запрос не должен перезаписать свежий.
    final generation = ++_generation;
    try {
      final results = await ref.read(educationApiProvider).universities(text.trim());
      if (mounted && generation == _generation) {
        setState(() {
          _results = results;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    }
  }

  Future<void> _request() async {
    final requested = await showDialog<String>(
      context: context,
      builder: (context) => _RequestDialog(initialName: _query.text.trim()),
    );
    if (requested != null && mounted) context.pop<UniversityPick>((university: null, requested: requested));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final results = _results;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SrSpace.xl),
          children: [
            FormHeader(title: 'Вуз', onBack: context.pop),
            TextField(
              controller: _query,
              autofocus: true,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _search,
              decoration: const InputDecoration(
                labelText: 'Название, сокращение или город',
                hintText: 'Например, «Первый мед» или «Казань»',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: SrSpace.l),
            if (_error case final error?)
              FormMessage(error.userMessage)
            else if (results == null)
              const Center(child: CircularProgressIndicator())
            else if (results.isEmpty)
              Text('Ничего не нашли. Проверьте написание или отправьте заявку.', style: theme.bodyMedium),
            for (final u in results ?? const <UniversityOption>[])
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: kMinTapTarget,
                title: Text(u.title),
                subtitle: Text(u.shortName.isEmpty ? u.city : '${u.name}, ${u.city}'),
                onTap: () => context.pop<UniversityPick>((university: u, requested: null)),
              ),
            const SizedBox(height: SrSpace.l),
            PillButton(
              label: 'Моего вуза нет',
              variant: PillButtonVariant.secondary,
              showArrow: false,
              onPressed: _request,
            ),
          ],
        ),
      ),
    );
  }
}

/// Возвращает название вуза из отправленной заявки.
class _RequestDialog extends ConsumerStatefulWidget {
  const _RequestDialog({required this.initialName});

  final String initialName;

  @override
  ConsumerState<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends ConsumerState<_RequestDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  final _city = TextEditingController();
  ApiException? _error;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(educationApiProvider).requestUniversity(_name.text.trim(), _city.text.trim());
      if (mounted) Navigator.pop(context, _name.text.trim());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      title: const Text('Добавить вуз'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Проверим и добавим в справочник — обычно за пару дней.'),
          const SizedBox(height: SrSpace.m),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: 'Название вуза', errorText: error?.field('name')),
          ),
          const SizedBox(height: SrSpace.s),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'Город'),
          ),
          if (error != null && error.field('name') == null) ...[
            const SizedBox(height: SrSpace.s),
            FormMessage(error.isThrottled ? 'Можно отправить не больше трёх заявок в сутки.' : error.userMessage),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        TextButton(onPressed: _busy ? null : _send, child: const Text('Отправить')),
      ],
    );
  }
}
