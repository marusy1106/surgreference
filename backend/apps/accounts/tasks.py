from celery import shared_task
from django.core.mail import EmailMessage


@shared_task(name="accounts.send_email", autoretry_for=(OSError,), retry_backoff=True, max_retries=5)
def send_email(to, subject, body, attachments=()):
    message = EmailMessage(subject=subject, body=body, to=[to])
    for name, content, mimetype in attachments:
        message.attach(name, content, mimetype)
    message.send()


@shared_task(name="accounts.cleanup")
def cleanup():
    from . import services

    services.cleanup_expired()


@shared_task(name="accounts.export_data")
def export_data(user_id):
    from . import services

    services.send_data_export(user_id)
