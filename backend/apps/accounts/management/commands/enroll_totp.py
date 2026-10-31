import io

import qrcode
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django_otp.plugins.otp_static.models import StaticDevice, StaticToken
from django_otp.plugins.otp_totp.models import TOTPDevice

from apps.accounts.models import User
from apps.audit.services import record_security_event

BACKUP_CODES = 10


class Command(BaseCommand):
    help = "Подключает второй фактор (TOTP + резервные коды) сотруднику. Без него админка не откроется."

    def add_arguments(self, parser):
        parser.add_argument("email")
        parser.add_argument("--reset", action="store_true", help="заменить существующие устройства (утерян телефон)")

    @transaction.atomic
    def handle(self, email, reset, **options):
        user = User.objects.filter(email=User.objects.normalize_email(email), is_staff=True, is_active=True).first()
        if user is None:
            raise CommandError("Активный сотрудник (is_staff) с таким email не найден")
        if TOTPDevice.objects.filter(user=user).exists() and not reset:
            raise CommandError("Второй фактор уже подключён. Для замены запустите с --reset")

        TOTPDevice.objects.filter(user=user).delete()
        StaticDevice.objects.filter(user=user).delete()
        totp = TOTPDevice.objects.create(user=user, name="Приложение-аутентификатор", confirmed=True)
        static = StaticDevice.objects.create(user=user, name="Резервные коды", confirmed=True)
        codes = [StaticToken.random_token() for _ in range(BACKUP_CODES)]
        StaticToken.objects.bulk_create(StaticToken(device=static, token=code) for code in codes)
        record_security_event("admin.mfa_enrolled", subject=user, reset=reset)

        qr = qrcode.QRCode(border=1)
        qr.add_data(totp.config_url)
        out = io.StringIO()
        qr.print_ascii(out=out, invert=True)
        self.stdout.write(out.getvalue())
        self.stdout.write(
            f"Отсканируйте QR-код приложением-аутентификатором или введите ссылку вручную:\n{totp.config_url}\n"
        )
        self.stdout.write("Резервные коды (каждый — на один вход, сохраните в менеджере паролей):")
        self.stdout.write("  " + "  ".join(codes))
        self.stdout.write(self.style.WARNING("Вывод этой команды содержит секреты — не сохраняйте его в логах."))
