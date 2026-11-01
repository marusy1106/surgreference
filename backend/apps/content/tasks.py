from celery import shared_task

from . import references


@shared_task(name="content.check_guideline_revisions")
def check_guideline_revisions():
    return references.check_revisions()
