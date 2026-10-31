from django.apps import AppConfig


class UniversitiesConfig(AppConfig):
    name = "apps.universities"
    label = "universities"
    verbose_name = "Вузы"

    def ready(self):
        from . import receivers  # noqa: F401
