import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_error.dart';
import '../../../core/ui/ui.dart';
import '../../learning/data/learning_models.dart';
import '../../learning/learning_providers.dart';
import 'quiz_result_screen.dart';
import 'quiz_screen.dart';

/// Прохождение теста: вопросы по одному с таймером → отправка ответов → результат с разбором.
class QuizFlowPage extends ConsumerStatefulWidget {
  const QuizFlowPage({super.key, required this.topicId});

  final String topicId;

  @override
  ConsumerState<QuizFlowPage> createState() => _QuizFlowPageState();
}

class _QuizFlowPageState extends ConsumerState<QuizFlowPage> {
  QuizSession? _session;
  QuizOutcome? _outcome;
  Object? _error;
  var _index = 0;
  var _selected = <int>{};
  final _answers = <String, Set<int>>{};
  final _expanded = <int>{};
  bool? _rated;
  Timer? _timer;
  var _left = Duration.zero;
  var _submitting = false;

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
    });
    try {
      final session = await ref.read(learningRepositoryProvider).startQuiz(widget.topicId);
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
      // Время вышло — фиксируем то, что выбрано (или пропуск) и идём дальше.
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

  Future<void> _answer() async {
    final session = _session!;
    _answers[session.questions[_index].id] = _selected;
    if (_index + 1 < session.questions.length) {
      setState(() {
        _index++;
        _selected = {};
      });
      _startTimer();
      return;
    }
    _timer?.cancel();
    setState(() => _submitting = true);
    try {
      final outcome = await ref.read(learningRepositoryProvider).submitQuiz(session.attemptId, _answers);
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
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _close() async {
    if (_outcome != null || _session == null) return context.pop();
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Прервать тест?'),
        content: const Text('Ответы не сохранятся, XP не начислится.'),
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
              message: error is ApiException ? error.userMessage : 'Для этой темы теста пока нет.',
              actionLabel: 'Назад',
              onAction: context.pop,
            ),
          ),
        ),
      );
    }
    final session = _session;
    if (session == null || _submitting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
          options: q.options,
          multiple: q.multiple,
          selected: _selected,
          timeLeft: _left.isNegative ? Duration.zero : _left,
          timeLimit: Duration(seconds: session.secondsPerQuestion),
        ),
        onSelect: _select,
        onAnswer: _answer,
        onClose: _close,
      ),
    );
  }

  Widget _result(QuizOutcome outcome) {
    return QuizResultScreen(
      result: QuizResultView(
        topic: outcome.topic,
        aura: outcome.aura,
        score: outcome.score,
        total: outcome.items.length,
        xpGained: outcome.xpGained,
        items: [
          for (final (i, item) in outcome.items.indexed)
            ResultItemView(
              question: item.question.text,
              correct: item.isCorrect,
              explanation: _expanded.contains(i) ? item.explanation : null,
              options: _expanded.contains(i)
                  ? [
                      for (final (o, text) in item.question.options.indexed)
                        (
                          text,
                          switch ((item.selected.contains(o), item.correct.contains(o))) {
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
      onMistakes: () {
        setState(() {
          _outcome = null;
          _index = 0;
          _answers.clear();
          _expanded.clear();
          _rated = null;
        });
        _start();
      },
    );
  }
}
