import uuid

from django.conf import settings
from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.db import models
from django.db.models import Q
from django.db.models.functions import Lower
from django.utils import timezone

from apps.core.models import Platform, TimeStampedModel, UUIDModel, choices_check


class UserManager(BaseUserManager):
    use_in_migrations = True

    @classmethod
    def normalize_email(cls, email):
        return (email or "").strip().lower()

    def _create_user(self, email, password, **extra_fields):
        if not email:
            raise ValueError("Email обязателен")
        user = self.model(email=self.normalize_email(email), **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.update(is_staff=True, is_superuser=True)
        extra_fields.setdefault("email_verified_at", timezone.now())
        return self._create_user(email, password, **extra_fields)


class UserTrustStatus(models.TextChoices):
    OK = "ok", "в порядке"
    SUSPICIOUS = "suspicious", "подозрительный"
    BLOCKED = "blocked", "заблокирован"


class User(AbstractBaseUser, PermissionsMixin):
    TrustStatus = UserTrustStatus

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField("email", max_length=254, unique=True)
    email_verified_at = models.DateTimeField("email подтверждён", null=True, blank=True)
    display_name = models.CharField("никнейм", max_length=32)
    first_name = models.CharField("имя", max_length=64, blank=True)
    is_active = models.BooleanField("активен", default=True)
    is_staff = models.BooleanField("сотрудник", default=False)
    leaderboard_opt_in = models.BooleanField("участвует в рейтингах", default=False)
    founder_number = models.PositiveSmallIntegerField("номер основателя", null=True, blank=True, unique=True)
    trust_status = models.CharField(max_length=16, choices=TrustStatus, default=TrustStatus.OK)
    deleted_at = models.DateTimeField("обезличен", null=True, blank=True)
    created_at = models.DateTimeField("зарегистрирован", default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    EMAIL_FIELD = "email"
    REQUIRED_FIELDS = ["display_name"]

    class Meta:
        verbose_name = "пользователь"
        verbose_name_plural = "пользователи"
        constraints = [
            models.CheckConstraint(condition=Q(email=Lower("email")), name="accounts_user_email_lowercase"),
            models.UniqueConstraint(Lower("display_name"), name="accounts_user_display_name_ci_unique"),
            choices_check("trust_status", UserTrustStatus),
            models.CheckConstraint(
                condition=Q(founder_number__isnull=True) | Q(founder_number__gte=1),
                name="accounts_user_founder_number_positive",
            ),
        ]
        indexes = [models.Index(fields=["email_verified_at"])]

    def __str__(self):
        return self.display_name

    @property
    def is_verified(self) -> bool:
        return self.email_verified_at is not None

    def clean(self):
        super().clean()
        self.email = self.__class__.objects.normalize_email(self.email)


class OneTimeCodePurpose(models.TextChoices):
    VERIFY_EMAIL = "verify_email", "подтверждение email"
    RESET_PASSWORD = "reset_password", "сброс пароля"
    CHANGE_EMAIL = "change_email", "смена email"
    DELETE_ACCOUNT = "delete_account", "удаление аккаунта"


class OneTimeCode(UUIDModel):
    """Одноразовые коды (хранится только хеш)."""

    Purpose = OneTimeCodePurpose

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="one_time_codes",
    )
    purpose = models.CharField(max_length=32, choices=Purpose)
    code_hash = models.CharField(max_length=128)
    target_email = models.EmailField(blank=True)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    consumed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [choices_check("purpose", OneTimeCodePurpose)]
        indexes = [
            models.Index(
                fields=["user", "purpose"],
                condition=Q(consumed_at__isnull=True),
                name="accounts_otc_active_idx",
            )
        ]


class UserSession(UUIDModel):
    """Сессия устройства. id = sid в access-токене."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="sessions")
    refresh_token_hash = models.CharField(max_length=64, unique=True)
    family_id = models.UUIDField(db_index=True)
    device_name = models.CharField(max_length=64, blank=True)
    platform = models.CharField(max_length=16, choices=Platform)
    app_version = models.CharField(max_length=32, blank=True)
    ip_last = models.GenericIPAddressField(null=True, blank=True)
    last_used_at = models.DateTimeField(default=timezone.now)
    expires_at = models.DateTimeField()
    revoked_at = models.DateTimeField(null=True, blank=True)
    revoke_reason = models.CharField(max_length=32, blank=True)

    class Meta:
        verbose_name = "сессия"
        verbose_name_plural = "сессии"
        constraints = [choices_check("platform", Platform)]
        indexes = [models.Index(fields=["user", "revoked_at"])]

    @property
    def is_active(self) -> bool:
        return self.revoked_at is None and self.expires_at > timezone.now()


class ConsentDocument(models.TextChoices):
    PD_PROCESSING = "pd_processing", "согласие на обработку ПД"
    TERMS = "terms", "пользовательское соглашение"
    PRIVACY_POLICY = "privacy_policy", "политика обработки ПД"
    MARKETING = "marketing", "рассылки"


class Consent(TimeStampedModel):
    Document = ConsentDocument

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="consents")
    document = models.CharField(max_length=32, choices=Document)
    document_version = models.CharField(max_length=16)
    accepted_at = models.DateTimeField(default=timezone.now)
    ip = models.GenericIPAddressField(null=True, blank=True)
    withdrawn_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = "согласие"
        verbose_name_plural = "согласия"
        constraints = [choices_check("document", ConsentDocument)]
        indexes = [models.Index(fields=["user", "document"])]


class DataSubjectRequestKind(models.TextChoices):
    ACCESS = "access", "сведения об обработке"
    EXPORT = "export", "выгрузка данных"
    RECTIFY = "rectify", "уточнение"
    DELETE = "delete", "удаление"
    WITHDRAW_CONSENT = "withdraw_consent", "отзыв согласия"


class DataSubjectRequestStatus(models.TextChoices):
    NEW = "new", "новый"
    IN_PROGRESS = "in_progress", "в работе"
    COMPLETED = "completed", "выполнен"
    REJECTED = "rejected", "отклонён"


class DataSubjectRequest(TimeStampedModel):
    """Запросы субъектов ПД (152-ФЗ): контроль сроков через due_at."""

    Kind = DataSubjectRequestKind

    Status = DataSubjectRequestStatus

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="pd_requests",
    )
    contact_email_hash = models.CharField(max_length=64, blank=True)
    kind = models.CharField(max_length=32, choices=Kind)
    status = models.CharField(max_length=16, choices=Status, default=Status.NEW)
    received_at = models.DateTimeField(default=timezone.now)
    due_at = models.DateTimeField()
    completed_at = models.DateTimeField(null=True, blank=True)
    handled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )
    note = models.TextField(blank=True)

    class Meta:
        verbose_name = "запрос субъекта ПД"
        verbose_name_plural = "запросы субъектов ПД"
        constraints = [
            choices_check("kind", DataSubjectRequestKind),
            choices_check("status", DataSubjectRequestStatus),
        ]
        indexes = [models.Index(fields=["status", "due_at"])]
