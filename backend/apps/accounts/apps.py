from django.apps import AppConfig


class AccountsConfig(AppConfig):
    name = "apps.accounts"
    label = "accounts"
    verbose_name = "Аккаунты"

    def ready(self):
        from django.db.models.signals import post_migrate

        from .roles import sync_roles

        post_migrate.connect(sync_roles, sender=self, dispatch_uid="accounts.sync_roles")
