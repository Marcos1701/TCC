# Generated migration for adding indicators cache

from decimal import Decimal
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0007_new_missions_system'),
    ]

    operations = [
        migrations.AddField(
            model_name='userprofile',
            name='cached_tps',
            field=models.DecimalField(
                blank=True,
                decimal_places=2,
                help_text='TPS em cache',
                max_digits=6,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='cached_rdr',
            field=models.DecimalField(
                blank=True,
                decimal_places=2,
                help_text='RDR em cache',
                max_digits=6,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='cached_ili',
            field=models.DecimalField(
                blank=True,
                decimal_places=2,
                help_text='ILI em cache',
                max_digits=6,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='indicators_updated_at',
            field=models.DateTimeField(
                blank=True,
                help_text='Última atualização dos indicadores em cache',
                null=True,
            ),
        ),
    ]
