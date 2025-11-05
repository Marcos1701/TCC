# Generated manually on 2025-11-05

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0021_friendship'),
    ]

    operations = [
        migrations.AddField(
            model_name='userprofile',
            name='is_first_access',
            field=models.BooleanField(default=True, help_text='Indica se é o primeiro acesso do usuário (para onboarding)'),
        ),
    ]
