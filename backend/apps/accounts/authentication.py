from drf_spectacular.extensions import OpenApiAuthenticationExtension
from rest_framework import authentication, exceptions

from . import tokens
from .models import User


class JWTAuthentication(authentication.BaseAuthentication):
    keyword = "Bearer"

    def authenticate(self, request):
        header = authentication.get_authorization_header(request).split()
        if not header or header[0].lower() != self.keyword.lower().encode():
            return None
        if len(header) != 2:
            raise exceptions.AuthenticationFailed("Неверный заголовок Authorization", code="token_invalid")
        try:
            payload = tokens.decode_access_token(header[1].decode())
        except (tokens.InvalidToken, UnicodeDecodeError):
            raise exceptions.AuthenticationFailed("Токен недействителен или истёк", code="token_invalid") from None
        if tokens.is_session_denylisted(payload["sid"]):
            raise exceptions.AuthenticationFailed("Сессия завершена", code="session_revoked")
        user = User.objects.filter(pk=payload["sub"], is_active=True, deleted_at__isnull=True).first()
        if user is None:
            raise exceptions.AuthenticationFailed("Пользователь не найден", code="token_invalid")
        return user, payload

    def authenticate_header(self, request):
        return self.keyword


class JWTAuthenticationScheme(OpenApiAuthenticationExtension):
    target_class = JWTAuthentication
    name = "bearerAuth"

    def get_security_definition(self, auto_schema):
        return {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"}
