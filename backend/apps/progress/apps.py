from django.apps import AppConfig


class ProgressConfig(AppConfig):
    name = "apps.progress"
    label = "progress"
    verbose_name = "Прогресс"

    def ready(self):
        from apps.assessment.signals import quiz_attempt_finished

        from . import services

        quiz_attempt_finished.connect(services.on_quiz_attempt_finished, dispatch_uid="progress.mastery")
