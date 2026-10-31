from django.contrib.auth.hashers import Argon2PasswordHasher


class TunedArgon2PasswordHasher(Argon2PasswordHasher):
    """Argon2id с параметрами под prod (~250–400 мс на хеш).

    Django использует вариант Argon2id. Параметры можно пересмотреть после замера на prod-сервере:
    хеши с прежними параметрами пересчитываются автоматически при следующем входе.
    """

    algorithm = "argon2"
    memory_cost = 64 * 1024  # KiB
    time_cost = 3
    parallelism = 2
