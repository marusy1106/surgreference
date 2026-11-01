from pathlib import Path

import environ

BASE_DIR = Path(__file__).resolve().parents[2]

env = environ.Env()
environ.Env.read_env(BASE_DIR.parent / ".env", overwrite=False)

SECRET_KEY = env("DJANGO_SECRET_KEY")
DEBUG = env.bool("DJANGO_DEBUG", default=False)
ALLOWED_HOSTS = env.list("DJANGO_ALLOWED_HOSTS", default=[])

LOCAL_APPS = [
    "apps.core",
    "apps.accounts",
    "apps.universities",
    "apps.content",
    "apps.assessment",
    "apps.cases",
    "apps.progress",
    "apps.gamification",
    "apps.leaderboards",
    "apps.billing",
    "apps.analytics",
    "apps.feedback",
    "apps.audit",
]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.postgres",
    "django_otp",
    "django_otp.plugins.otp_totp",
    "django_otp.plugins.otp_static",
    "rest_framework",
    "drf_spectacular",
    *LOCAL_APPS,
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django_otp.middleware.OTPMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

DATABASES = {"default": env.db("DATABASE_URL")}
DATABASES["default"]["ATOMIC_REQUESTS"] = False
DATABASES["default"]["CONN_MAX_AGE"] = env.int("DB_CONN_MAX_AGE", default=60)
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

REDIS_URL = env("REDIS_URL", default="redis://localhost:6379/0")
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": REDIS_URL,
    }
}

# --- Аутентификация ---------------------------------------------------------
AUTH_USER_MODEL = "accounts.User"

# Argon2id первым: новые хеши создаются им, старые пересчитываются при входе.
PASSWORD_HASHERS = [
    "apps.accounts.hashers.TunedArgon2PasswordHasher",
    "django.contrib.auth.hashers.Argon2PasswordHasher",
]

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
        "OPTIONS": {"user_attributes": ("email", "display_name", "first_name")},
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
        "OPTIONS": {"min_length": 10},
    },
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
]

# Access — JWT HS256 с kid для ротации ключей: JWT_SIGNING_KEYS="k2=...,k1=...", JWT_ACTIVE_KID=k2.
# Старые ключи остаются в списке на время жизни access-токена, затем удаляются.
JWT_SIGNING_KEYS = env.dict("JWT_SIGNING_KEYS", default={})
JWT_ACTIVE_KID = env("JWT_ACTIVE_KID", default="")
if not JWT_SIGNING_KEYS:
    JWT_SIGNING_KEYS, JWT_ACTIVE_KID = {"dev": SECRET_KEY}, "dev"
JWT_ISSUER = "surgreference"
ACCESS_TOKEN_TTL = 15 * 60
REFRESH_TOKEN_SLIDING_TTL = 30 * 24 * 3600
REFRESH_TOKEN_ABSOLUTE_TTL = 90 * 24 * 3600
MAX_ACTIVE_SESSIONS = 10

ONE_TIME_CODE_TTL = 15 * 60
ONE_TIME_CODE_MAX_ATTEMPTS = 5
UNVERIFIED_ACCOUNT_TTL_DAYS = 7
LOGIN_LOCKOUT_FAILURES = 10
LOGIN_LOCKOUT_SECONDS = 15 * 60

OTP_TOTP_ISSUER = "SurgReference"
# Второй фактор для входа в админку. Выключать можно только локально (dev), в prod — запрещено.
ADMIN_REQUIRE_OTP = True

# --- Локализация --------------------------------------------------------------
LANGUAGE_CODE = "ru"
TIME_ZONE = "UTC"
# Граница учебного дня (серия, лимит XP, недели рейтинга). Часовой пояс устройства — после MVP.
LEARNING_TIME_ZONE = env("LEARNING_TIME_ZONE", default="Europe/Moscow")
XP_DAILY_CAP = env.int("XP_DAILY_CAP", default=500)
USE_I18N = True
USE_TZ = True

# --- Статика и файлы ---------------------------------------------------------
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

S3_BUCKET = env("S3_BUCKET", default="")
if S3_BUCKET:
    STORAGES = {
        "default": {
            "BACKEND": "storages.backends.s3.S3Storage",
            "OPTIONS": {
                "bucket_name": S3_BUCKET,
                "endpoint_url": env("S3_ENDPOINT_URL"),
                "region_name": env("S3_REGION", default="ru-central1"),
                "access_key": env("S3_ACCESS_KEY_ID"),
                "secret_key": env("S3_SECRET_ACCESS_KEY"),
                "default_acl": "private",
                "querystring_auth": True,
                "querystring_expire": 600,
                "file_overwrite": False,
            },
        },
        "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
    }
else:
    MEDIA_ROOT = BASE_DIR / "media"
    MEDIA_URL = "media/"

# --- DRF / OpenAPI ------------------------------------------------------------
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": ["apps.accounts.authentication.JWTAuthentication"],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_PARSER_CLASSES": ["rest_framework.parsers.JSONParser"],
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "EXCEPTION_HANDLER": "apps.core.api.exceptions.exception_handler",
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {"anon": "60/min", "user": "120/min"},
    "UNAUTHENTICATED_USER": None,
    # Сколько доверенных прокси перед приложением (для IP в лимитах и журнале).
    "NUM_PROXIES": env.int("NUM_PROXIES", default=0),
}

SPECTACULAR_SETTINGS = {
    "TITLE": "SurgReference API",
    "DESCRIPTION": "Учебная платформа. Не предназначена для диагностики и лечения.",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "SCHEMA_PATH_PREFIX": r"/api/v1",
    "COMPONENT_SPLIT_REQUEST": True,
}
API_DOCS_ENABLED = env.bool("API_DOCS_ENABLED", default=DEBUG)

# --- Celery -----------------------------------------------------------------------
CELERY_BROKER_URL = env("CELERY_BROKER_URL", default=REDIS_URL)
CELERY_RESULT_BACKEND = None
CELERY_TASK_ALWAYS_EAGER = False
CELERY_TASK_ACKS_LATE = True
CELERY_WORKER_PREFETCH_MULTIPLIER = 1
CELERY_TIMEZONE = "UTC"
CELERY_BEAT_SCHEDULE = {
    "accounts-cleanup": {"task": "accounts.cleanup", "schedule": 3600},
    "assessment-expire-attempts": {"task": "assessment.expire_attempts", "schedule": 3600},
}

# --- Почта ----------------------------------------------------------------------
EMAIL_CONFIG = env.email("EMAIL_URL", default="consolemail://")
vars().update(EMAIL_CONFIG)
DEFAULT_FROM_EMAIL = env("DEFAULT_FROM_EMAIL", default="SurgReference <no-reply@localhost>")

# --- Клиентские параметры ---------------------------------------------------------
MIN_APP_VERSION = env("MIN_APP_VERSION", default="1.0.0")
LEGAL_DOCUMENT_VERSIONS = {
    "pd_processing": env("LEGAL_PD_PROCESSING_VERSION", default="1.0"),
    "terms": env("LEGAL_TERMS_VERSION", default="1.0"),
    "privacy_policy": env("LEGAL_PRIVACY_POLICY_VERSION", default="1.0"),
}

# --- Безопасность (общие) -------------------------------------------------------
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Strict"
SESSION_COOKIE_AGE = 30 * 60
SESSION_SAVE_EVERY_REQUEST = True
CSRF_COOKIE_SAMESITE = "Strict"
X_FRAME_OPTIONS = "DENY"
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "same-origin"
DATA_UPLOAD_MAX_MEMORY_SIZE = 1 * 1024 * 1024

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "plain": {"format": "%(asctime)s %(levelname)s %(name)s %(message)s"},
    },
    "handlers": {"console": {"class": "logging.StreamHandler", "formatter": "plain"}},
    "root": {"handlers": ["console"], "level": env("LOG_LEVEL", default="INFO")},
}
