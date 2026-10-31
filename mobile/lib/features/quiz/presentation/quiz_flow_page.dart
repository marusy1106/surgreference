import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/api/api_error.dart';
import '../../../core/ui/ui.dart';
import '../../learning/data/learning_models.dart';
import '../../learning/learning_providers.dart';
import 'quiz_result_screen.dart';
import 'quiz_screen.dart';

/// Прохождение теста: ответ на каждый вопрос уходит на сервер сразу, проверка — при завершении,
/// затем разбор каждого варианта.
class QuizFlowPage extends ConsumerStatefulWidget {
  const QuizFlowPage({super.key, required this.quizId});

  final String quizId;

  @override
  ConsumerState<QuizFlowPage> createState() => _QuizFlowPageState();
}

class _QuizFlowPageState extends ConsumerState<QuizFlowPage> {
  QuizSession? _session;
  QuizOutcome? _outcome;
  Object? _error;
  var _index = 0;
  var _selected = <int>{};
  final _expanded = <int>{};
  bool? _rated;
  Timer? _timer;
  var _left = Duration.zero;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _session = null;
      _outcome = null;
      _index = 0;
      _selected = {};
      _expanded.clear();
      _rated = null;
    });
    try {
      final session = await ref.read(learningRepositoryProvider).startQuiz(widget.quizId);
      if (!mounted) return;
      setState(() => _session = session);
      _startTimer();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _left = Duration(seconds: _session!.secondsPerQuestion);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _left -= const Duration(seconds: 1));
      // Время вышло: выбранное уходит как ответ, без выбора — вопрос пропущен.
      if (_left <= Duration.zero) _answer();
    });
  }

  void _select(int option) {
    final question = _session!.questions[_index];
    setState(() {
      if (!question.multiple) {
        _selected = {option};
      } else if (!_selected.remove(option)) {
        _selected = {..._selected, option};
      }
    });
  }

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _answer() async {
    if (_busy) return;
    final session = _session!;
    final question = session.questions[_index];
    _timer?.cancel();
    setState(() => _busy = true);
    final repository = ref.read(learningRepositoryProvider);
    try {
      if (_selected.isNotEmpty) {
        await repository.answer(session.attemptId, question.id, [for (final i in _selected) question.options[i].id]);
      }
      if (_index + 1 < session.questions.length) {
        setState(() {
          _index++;
          _selected = {};
        });
        _startTimer();
        return;
      }
      final outcome = await repository.finishQuiz(session.attemptId);
      invalidateStats(ref);
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        // Неверные ответы раскрыты сразу — ради разбора всё и затевалось.
        _expanded.addAll([
          for (final (i, item) in outcome.items.indexed)
            if (!item.isCorrect) i,
        ]);
      });
    } on ApiException catch (e) {
      // Ответ не сохранился (нет сети) — остаёмся на вопросе, выбор не теряем.
      if (mounted) {
        _message(e.userMessage);
        _startTimer();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_outcome != null || _session == null) return context.pop();
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Прервать тест?'),
        content: const Text('Попытка не будет засчитана, XP не начислится.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Продолжить тест')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Прервать')),
        ],
      ),
    );
    if (leave == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Тест не загрузился',
              message: error is ApiException ? error.userMessage : 'Попробуйте ещё раз.',
              actionLabel: 'Повторить',
              onAction: _start,
            ),
          ),
        ),
      );
    }
    final session = _session;
    if (session == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final outcome = _outcome;
    if (outcome != null) return _result(outcome);

    final q = session.questions[_index];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: QuizScreen(
        question: QuizQuestionView(
          index: _index,
          total: session.questions.length,
          topic: session.topic,
          aura: session.aura,
          text: q.text,
          options: [for (final o in q.options) o.text],
          multiple: q.multiple,
          selected: _selected,
          timeLeft: _left.isNegative ? Duration.zero : _left,
          timeLimit: Duration(seconds: session.secondsPerQuestion),
        ),
        onSelect: _busy ? null : _select,
        onAnswer: _busy ? null : _answer,
        onClose: _close,
      ),
    );
  }

  /// Разбор: общий комментарий и объяснение выбранных и правильных вариантов.
  static String _explanation(QuizReviewItem item) {
    final lines = [
      if (item.explanation.isNotEmpty) item.explanation,
      for (final o in item.options)
        if ((o.selected || o.isCorrect) && o.explanation.isNotEmpty) '• ${o.text}: ${o.explanation}',
    ];
    return lines.join('\n');
  }

  Widget _result(QuizOutcome outcome) {
    final lessonId = outcome.lessonId;
    return QuizResultScreen(
      result: QuizResultView(
        topic: outcome.topic,
        aura: outcome.aura,
        score: outcome.correct,
        total: outcome.items.length,
        xpGained: outcome.xpGained,
        items: [
          for (final (i, item) in outcome.items.indexed)
            ResultItemView(
              question: item.text,
              correct: item.isCorrect,
              explanation: _expanded.contains(i) ? _explanation(item) : null,
              options: _expanded.contains(i)
                  ? [
                      for (final o in item.options)
                        (
                          o.text,
                          switch ((o.selected, o.isCorrect)) {
                            (true, true) => AnswerState.correct,
                            (true, false) => AnswerState.incorrect,
                            (false, true) => AnswerState.missedCorrect,
                            (false, false) => AnswerState.idle,
                          },
                        ),
                    ]
                  : const [],
            ),
        ],
      ),
      rated: _rated,
      onItemTap: (i) => setState(() => _expanded.contains(i) ? _expanded.remove(i) : _expanded.add(i)),
      onRate: (useful) => setState(() => _rated = useful),
      onClose: context.pop,
      onMistakes: _start,
      onLesson: lessonId == null ? null : () => context.pushReplacement(Routes.lesson(lessonId)),
    );
  }
}
