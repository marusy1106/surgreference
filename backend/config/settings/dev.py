from .base import *  # noqa: F403
from .base import env

DEBUG = True
ALLOWED_HOSTS = ["localhost", "127.0.0.1", "[::1]", "10.0.2.2"]
API_DOCS_ENABLED = True

# Без docker compose воркера Celery нет: письма (коды) отправляются сразу в процессе API.
CELERY_TASK_ALWAYS_EAGER = env.bool("CELERY_TASK_ALWAYS_EAGER", default=False)

# Локально админка пускает по паролю, без кода из приложения-аутентификатора. В prod код обязателен.
ADMIN_REQUIRE_OTP = env.bool("ADMIN_REQUIRE_OTP", default=False)
