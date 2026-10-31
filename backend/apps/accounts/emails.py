"""Тексты писем. Отправка — через Celery (tasks.send_email); содержимое писем в логи не пишется."""

from .tasks import send_email

FOOTER = "\n\n—\nSurgReference, учебная платформа. Если вы не совершали это действие, просто проигнорируйте письмо."


def _send(to, subject, body, attachments=()):
    send_email.delay(to, subject, body + FOOTER, list(attachments))


def verification_code(email, code):
    _send(email, f"{code} — код подтверждения SurgReference", f"Ваш код подтверждения: {code}\nКод действует 15 минут.")


def registration_attempt(email):
    _send(
        email,
        "Попытка регистрации в SurgReference",
        "Кто-то попытался зарегистрироваться в SurgReference с вашим адресом. Аккаунт у вас уже есть.\n"
        "Если это были вы — войдите или восстановите пароль в приложении.",
    )


def password_reset_code(email, code):
    _send(email, f"{code} — код для сброса пароля", f"Код для сброса пароля: {code}\nКод действует 15 минут.")


def password_changed(email):
    _send(
        email,
        "Пароль SurgReference изменён",
        "Пароль вашего аккаунта изменён, остальные устройства вышли из аккаунта.\n"
        "Если это были не вы — сразу восстановите пароль в приложении.",
    )


def login_locked(email):
    _send(
        email,
        "Подозрительные попытки входа",
        "Было много неудачных попыток войти в ваш аккаунт, вход временно приостановлен на 15 минут.\n"
        "Если это были не вы — смените пароль.",
    )


def deletion_code(email, code):
    _send(email, f"{code} — код для удаления аккаунта", f"Код для удаления аккаунта: {code}\nКод действует 15 минут.")


def account_deleted(email):
    _send(
        email,
        "Аккаунт SurgReference удалён",
        "Ваш аккаунт удалён, персональные данные обезличены. Резервные копии очищаются в течение 30 дней.",
    )


def session_family_revoked(email):
    _send(
        email,
        "Сессия завершена по соображениям безопасности",
        "Мы заметили повторное использование токена входа и завершили сессию на одном из устройств.\n"
        "Войдите заново. Если вы не узнаёте это устройство — смените пароль.",
    )


def data_export(email, payload_json):
    _send(
        email,
        "Выгрузка ваших данных SurgReference",
        "Во вложении — данные вашего аккаунта в формате JSON: профиль, согласия, устройства, учебный профиль.",
        attachments=[("surgreference-export.json", payload_json, "application/json")],
    )


def roles_changed(email, subject_name, actor_name):
    _send(
        email,
        "Изменены роли сотрудника SurgReference",
        f"Сотрудник {actor_name} изменил роли пользователя {subject_name}. Подробности — в журнале безопасности.",
    )
