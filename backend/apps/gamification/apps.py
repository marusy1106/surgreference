from django.apps import AppConfig


class GamificationConfig(AppConfig):
    name = "apps.gamification"
    label = "gamification"
    verbose_name = "Геймификация"

    def ready(self):
        from apps.assessment.signals import quiz_attempt_finished
        from apps.cases.signals import case_attempt_finished
        from apps.progress.signals import lesson_completed

        from . import services

        lesson_completed.connect(services.on_lesson_completed, dispatch_uid="gamification.lesson")
        quiz_attempt_finished.connect(services.on_quiz_attempt_finished, dispatch_uid="gamification.quiz")
        case_attempt_finished.connect(services.on_case_attempt_finished, dispatch_uid="gamification.case")
