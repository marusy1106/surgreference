import pytest
from django.contrib.contenttypes.models import ContentType

from apps.cases.models import ClinicalCase
from apps.content import editorial
from apps.content.editorial import EditorialError
from apps.content.models import ContentSource, Discipline, Source

pytestmark = [pytest.mark.django_db, pytest.mark.usefixtures("demo_content")]


@pytest.fixture
def case():
    return ClinicalCase.objects.get()


def test_new_version_copies_steps_and_links(case, staff):
    first, *rest = case.steps.all()
    first.choices.update(next_step=rest[-1])
    copy = editorial.new_version(case, staff("content_author"))

    old_steps = list(case.steps.all())
    new_steps = list(copy.steps.all())
    assert [s.content for s in new_steps] == [s.content for s in old_steps]
    new_ids = {s.pk for s in new_steps}
    links = [c.next_step_id for s in new_steps for c in s.choices.all() if c.next_step_id]
    assert links
    assert set(links) <= new_ids, "choices point to the copied steps, not the old ones"


def test_approval_requires_synthetic_patient_attestation(case, staff):
    author, reviewer = staff("content_author"), staff("medical_reviewer")
    Discipline.objects.get(pk=case.discipline_id).reviewers.add(reviewer)
    draft = editorial.new_version(case, author)
    ContentSource.objects.create(
        content_type=ContentType.objects.get_for_model(draft), object_id=draft.pk, source=Source.objects.first()
    )
    editorial.submit(draft, author)

    with pytest.raises(EditorialError, match="вымышлен"):
        editorial.review(draft, reviewer, "approve")
    approved = editorial.review(draft, reviewer, "approve", attest_synthetic=True)

    assert approved.synthetic_attested_by == reviewer
