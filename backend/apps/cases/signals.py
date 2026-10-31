from django.dispatch import Signal

# Кейс пройден до конца. Аргументы: attempt (CaseAttempt со статусом finished).
case_attempt_finished = Signal()
