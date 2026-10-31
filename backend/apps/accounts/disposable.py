"""Блок-лист одноразовых почтовых доменов (дополняется по журналу регистраций)."""

DISPOSABLE_DOMAINS = frozenset(
    {
        "10minutemail.com",
        "dropmail.me",
        "guerrillamail.com",
        "mailinator.com",
        "mailnesia.com",
        "mohmal.com",
        "sharklasers.com",
        "temp-mail.org",
        "tempmail.plus",
        "throwawaymail.com",
        "trashmail.com",
        "yopmail.com",
    }
)


def is_disposable_email(email: str) -> bool:
    return email.rpartition("@")[2] in DISPOSABLE_DOMAINS
