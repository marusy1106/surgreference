import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="usersession",
            name="previous_refresh_hash",
            field=models.CharField(blank=True, db_index=True, max_length=64),
        ),
        migrations.AddField(
            model_name="usersession",
            name="absolute_expires_at",
            field=models.DateTimeField(
                default=django.utils.timezone.now, verbose_name="истекает (абсолютный срок)"
            ),
            preserve_default=False,
        ),
        migrations.AlterField(
            model_name="usersession",
            name="expires_at",
            field=models.DateTimeField(verbose_name="истекает (скользящий срок)"),
        ),
    ]
