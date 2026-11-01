from .base import *  # noqa: F403
from .base import ADMIN_REQUIRE_OTP, JWT_ACTIVE_KID, JWT_SIGNING_KEYS, env

DEBUG = False

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = env.bool("SECURE_SSL_REDIRECT", default=True)
SECURE_HSTS_SECONDS = 60 * 60 * 24 * 365
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[])

if JWT_ACTIVE_KID == "dev":
    raise RuntimeError("В prod задайте JWT_SIGNING_KEYS и JWT_ACTIVE_KID")
if JWT_ACTIVE_KID not in JWT_SIGNING_KEYS or min(map(len, JWT_SIGNING_KEYS.values())) < 32:
    raise RuntimeError("JWT_ACTIVE_KID должен быть среди JWT_SIGNING_KEYS, длина каждого ключа — не меньше 32 символов")

if not env("S3_BUCKET", default=""):
    raise RuntimeError("В prod файлы хранятся только в S3: задайте S3_BUCKET и ключи доступа")

if not ADMIN_REQUIRE_OTP:
    raise RuntimeError("В prod вход в админку только со вторым фактором (ADMIN_REQUIRE_OTP)")
