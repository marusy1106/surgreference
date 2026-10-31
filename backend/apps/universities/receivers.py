from django.dispatch import receiver

from apps.accounts.signals import account_deleted, export_requested

from .models import EducationProfile, EducationProfileHistory


@receiver(account_deleted, dispatch_uid="universities.account_deleted")
def delete_education_profile(sender, user, **kwargs):
    EducationProfile.objects.filter(user=user).delete()
    EducationProfileHistory.objects.filter(user=user).delete()


@receiver(export_requested, dispatch_uid="universities.export")
def export_education(sender, user, **kwargs):
    profile = EducationProfile.objects.filter(user=user).select_related("university", "faculty", "specialty").first()
    history = list(EducationProfileHistory.objects.filter(user=user).values("snapshot", "changed_at"))
    if profile is None and not history:
        return None
    current = None
    if profile is not None:
        current = {
            "status": profile.status,
            "university": str(profile.university) if profile.university else None,
            "faculty": str(profile.faculty) if profile.faculty else None,
            "specialty": str(profile.specialty) if profile.specialty else None,
            "course": profile.course,
            "study_year": profile.study_year,
            "graduation_year": profile.graduation_year,
            "verification_status": profile.verification_status,
        }
    return "education", {"current": current, "history": history}
