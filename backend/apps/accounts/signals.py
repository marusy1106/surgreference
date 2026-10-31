"""Сигналы для модулей, которые лежат выше accounts по слоям и хранят данные пользователя."""

from django.dispatch import Signal

# Аккаунт обезличен: модули удаляют свои ПД пользователя. kwargs: user.
account_deleted = Signal()

# Сбор выгрузки данных субъекта ПД. kwargs: user. Получатель возвращает (раздел, данные).
export_requested = Signal()
