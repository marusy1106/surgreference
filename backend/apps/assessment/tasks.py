from celery import shared_task

from . import services


@shared_task(name="assessment.expire_attempts")
def expire_attempts():
    return services.expire_attempts()
