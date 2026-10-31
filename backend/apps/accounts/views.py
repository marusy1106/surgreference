from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from . import selectors, services
from . import serializers as s
from .services import Device


def _device(data):
    return Device(**data["device"])


def _tokens(pair):
    return Response(s.TokenPairSerializer(pair).data)


def _accepted(state):
    return Response({"status": state}, status=status.HTTP_202_ACCEPTED)


class PublicView(APIView):
    """Эндпоинты без токена: лимиты по IP/email задаются в services, поверх — общий anon-лимит."""

    authentication_classes = []
    permission_classes = [AllowAny]
    serializer_class = None

    def get_authenticate_header(self, request):
        # Без этого DRF превращает 401 (неверный пароль/refresh) в 403 для view без authentication_classes.
        return "Bearer"

    def validated(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        return serializer.validated_data


class RegisterView(PublicView):
    serializer_class = s.RegisterSerializer

    @extend_schema(responses={202: s.StatusSerializer}, tags=["auth"])
    def post(self, request):
        services.register(**self.validated(request), request=request)
        return _accepted("verification_sent")


class VerifyEmailView(PublicView):
    serializer_class = s.VerifyEmailSerializer

    @extend_schema(responses=s.TokenPairSerializer, tags=["auth"])
    def post(self, request):
        data = self.validated(request)
        return _tokens(
            services.verify_email(email=data["email"], code=data["code"], device=_device(data), request=request)
        )


class ResendCodeView(PublicView):
    serializer_class = s.EmailSerializer

    @extend_schema(responses={202: s.StatusSerializer}, tags=["auth"])
    def post(self, request):
        services.resend_verification(self.validated(request)["email"], request)
        return _accepted("verification_sent")


class LoginView(PublicView):
    serializer_class = s.LoginSerializer

    @extend_schema(responses=s.TokenPairSerializer, tags=["auth"])
    def post(self, request):
        data = self.validated(request)
        return _tokens(
            services.login(email=data["email"], password=data["password"], device=_device(data), request=request)
        )


class RefreshView(PublicView):
    serializer_class = s.RefreshSerializer

    @extend_schema(responses=s.TokenPairSerializer, tags=["auth"])
    def post(self, request):
        return _tokens(services.refresh_session(self.validated(request)["refresh"], request))


class ForgotPasswordView(PublicView):
    serializer_class = s.EmailSerializer

    @extend_schema(responses={202: s.StatusSerializer}, tags=["auth"])
    def post(self, request):
        services.forgot_password(self.validated(request)["email"], request)
        return _accepted("code_sent_if_exists")


class ResetPasswordView(PublicView):
    serializer_class = s.ResetPasswordSerializer

    @extend_schema(responses=s.StatusSerializer, tags=["auth"])
    def post(self, request):
        services.reset_password(**self.validated(request), request=request)
        return Response({"status": "password_reset"})


class LogoutView(APIView):
    @extend_schema(request=None, responses={204: None}, tags=["auth"])
    def post(self, request):
        services.logout(request.user, request.auth["sid"], request=request)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ChangePasswordView(APIView):
    serializer_class = s.ChangePasswordSerializer

    @extend_schema(responses=s.StatusSerializer, tags=["auth"])
    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.change_password(request.user, sid=request.auth["sid"], request=request, **serializer.validated_data)
        return Response({"status": "password_changed"})


class SessionListView(APIView):
    @extend_schema(responses=s.SessionSerializer(many=True), tags=["auth"])
    def get(self, request):
        sessions = selectors.active_sessions(request.user)
        return Response(s.SessionSerializer(sessions, many=True, context={"sid": request.auth["sid"]}).data)

    @extend_schema(
        summary="Завершить все сессии, кроме текущей",
        operation_id="auth_sessions_destroy_others",
        responses={204: None},
        tags=["auth"],
    )
    def delete(self, request):
        services.revoke_other_sessions(request.user, request.auth["sid"], request=request)
        return Response(status=status.HTTP_204_NO_CONTENT)


class SessionDetailView(APIView):
    @extend_schema(responses={204: None}, tags=["auth"])
    def delete(self, request, session_id):
        # Чужая или уже завершённая сессия → 404, без раскрытия её существования.
        session = get_object_or_404(selectors.active_sessions(request.user), pk=session_id)
        services.revoke_session(request.user, session.pk, request=request)
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    serializer_class = s.UserSerializer

    @extend_schema(tags=["me"])
    def get(self, request):
        return Response(s.UserSerializer(request.user).data)

    @extend_schema(tags=["me"])
    def patch(self, request):
        serializer = s.UserSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class DeletionCodeView(APIView):
    @extend_schema(request=None, responses={202: s.StatusSerializer}, tags=["me"])
    def post(self, request):
        services.request_account_deletion(request.user, request)
        return _accepted("code_sent")


class DeleteAccountView(APIView):
    serializer_class = s.CodeSerializer

    @extend_schema(summary="Удалить аккаунт (обезличивание) по коду из письма", responses={204: None}, tags=["me"])
    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.delete_account(request.user, serializer.validated_data["code"], request)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ExportView(APIView):
    @extend_schema(request=None, responses={202: s.StatusSerializer}, tags=["me"])
    def post(self, request):
        services.request_data_export(request.user, request)
        return _accepted("export_scheduled")


class ConsentListView(APIView):
    @extend_schema(responses=s.ConsentSerializer(many=True), tags=["me"])
    def get(self, request):
        return Response(s.ConsentSerializer(request.user.consents.order_by("-accepted_at"), many=True).data)
