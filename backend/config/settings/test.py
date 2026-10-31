from .base import *  # noqa: F403

# Быстрый хешер для тестов; Argon2id проверяется отдельным тестом на prod-настройках хешера.
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
CACHES = {"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}}
CELERY_TASK_ALWAYS_EAGER = True
EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
API_DOCS_ENABLED = True
