from django.core.validators import RegexValidator
from rest_framework import serializers

from apps.core.models import Platform

from .models import Consent, User, UserSession

display_name_validator = RegexValidator(
    r"^[0-9A-Za-zА-Яа-яЁё_.-]{3,32}$",
    "От 3 до 32 символов: буквы, цифры, «_», «.», «-»",
)
code_validator = RegexValidator(r"^\d{6}$", "Код — 6 цифр")


def password_field():
    return serializers.CharField(write_only=True, max_length=128, trim_whitespace=False)


class DeviceSerializer(serializers.Serializer):
    platform = serializers.ChoiceField(choices=Platform.choices)
    device_name = serializers.CharField(max_length=64, required=False, default="", allow_blank=True)
    app_version = serializers.CharField(max_length=32, required=False, default="", allow_blank=True)


class ConsentInputSerializer(serializers.Serializer):
    document = serializers.ChoiceField(choices=Consent.Document.choices)
    version = serializers.CharField(max_length=16)


class RegisterSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)
    password = password_field()
    display_name = serializers.CharField(max_length=32, validators=[display_name_validator])
    consents = ConsentInputSerializer(many=True, allow_empty=False)


class EmailSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)


class VerifyEmailSerializer(EmailSerializer):
    code = serializers.CharField(validators=[code_validator])
    device = DeviceSerializer()


class LoginSerializer(EmailSerializer):
    password = password_field()
    device = DeviceSerializer()


class RefreshSerializer(serializers.Serializer):
    refresh = serializers.CharField(max_length=128)


class ResetPasswordSerializer(EmailSerializer):
    code = serializers.CharField(validators=[code_validator])
    new_password = password_field()


class ChangePasswordSerializer(serializers.Serializer):
    old_password = password_field()
    new_password = password_field()


class CodeSerializer(serializers.Serializer):
    code = serializers.CharField(validators=[code_validator])


class UserSerializer(serializers.ModelSerializer):
    email_verified = serializers.BooleanField(source="is_email_verified", read_only=True)

    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "email_verified",
            "display_name",
            "first_name",
            "leaderboard_opt_in",
            "founder_number",
            "created_at",
        )
        read_only_fields = ("id", "email", "leaderboard_opt_in", "founder_number", "created_at")
        extra_kwargs = {"display_name": {"validators": [display_name_validator]}}

    def validate_display_name(self, value):
        taken = User.objects.filter(display_name__iexact=value).exclude(pk=self.instance.pk).exists()
        if taken:
            raise serializers.ValidationError("Этот никнейм уже занят")
        return value


class TokenPairSerializer(serializers.Serializer):
    access = serializers.CharField()
    refresh = serializers.CharField()
    token_type = serializers.CharField()
    expires_in = serializers.IntegerField(help_text="Срок жизни access-токена, секунд")
    session_id = serializers.UUIDField()
    user = UserSerializer()


class SessionSerializer(serializers.ModelSerializer):
    is_current = serializers.SerializerMethodField()

    class Meta:
        model = UserSession
        fields = ("id", "platform", "device_name", "app_version", "created_at", "last_used_at", "is_current")

    def get_is_current(self, obj) -> bool:
        return str(obj.pk) == self.context.get("sid")


class ConsentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Consent
        fields = ("document", "document_version", "accepted_at", "withdrawn_at")


class StatusSerializer(serializers.Serializer):
    status = serializers.CharField()
