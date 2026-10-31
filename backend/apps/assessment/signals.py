from django.dispatch import Signal

# Отправляется внутри транзакции завершения попытки; получатели — progress (освоение) и gamification (XP).
# Аргументы: attempt (QuizAttempt со статусом finished).
quiz_attempt_finished = Signal()
