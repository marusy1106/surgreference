from rest_framework import exceptions
from rest_framework.views import exception_handler as drf_exception_handler


def exception_handler(exc, context):
    """Единый формат ошибок: {"error": {"code", "message", "fields"}}."""
    response = drf_exception_handler(exc, context)
    if response is None:
        return None

    code = getattr(exc, "default_code", "error")
    fields = None
    if isinstance(exc, exceptions.ValidationError):
        code = "validation_error"
        message = "Проверьте введённые данные"
        fields = response.data if isinstance(response.data, dict) else {"non_field_errors": response.data}
    else:
        detail = response.data.get("detail") if isinstance(response.data, dict) else response.data
        message = str(detail) if detail else "Ошибка"
        code = getattr(detail, "code", code)

    payload = {"code": code, "message": message}
    if fields:
        payload["fields"] = fields
    response.data = {"error": payload}
    return response
