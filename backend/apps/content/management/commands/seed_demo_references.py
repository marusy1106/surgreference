from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.content.demo import attach_to_demo_lesson, seed_references


class Command(BaseCommand):
    help = "Демо-справочники МКБ-10 и КР, ссылки на них в демо-уроке (только для разработки)"

    def add_arguments(self, parser):
        parser.add_argument("--force", action="store_true", help="Разрешить запуск при DEBUG=False")

    def handle(self, *args, force=False, **options):
        if not settings.DEBUG and not force:
            raise CommandError("Демо-данные не для продакшена. Если это стенд для беты — добавьте --force.")
        guidelines = seed_references()
        attached = attach_to_demo_lesson(guidelines["Острый аппендицит у взрослых"])
        self.stdout.write(
            self.style.SUCCESS(
                f"Справочники: КР {len(guidelines)}, ссылки в демо-уроке {'добавлены' if attached else 'уже есть'}."
            )
        )
