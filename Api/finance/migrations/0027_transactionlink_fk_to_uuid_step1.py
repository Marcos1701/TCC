# Generated migration for TransactionLink FK to UUID - Step 1: Add temporary UUID FK fields

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0026_populate_uuids'),
    ]

    operations = [
        # Step 1a: Adicionar campos UUID temporários (permitir null inicialmente)
        migrations.AddField(
            model_name='transactionlink',
            name='source_transaction_uuid_temp',
            field=models.UUIDField(
                null=True,
                blank=True,
                db_index=True,
                help_text="Campo temporário para migração FK para UUID"
            ),
        ),
        migrations.AddField(
            model_name='transactionlink',
            name='target_transaction_uuid_temp',
            field=models.UUIDField(
                null=True,
                blank=True,
                db_index=True,
                help_text="Campo temporário para migração FK para UUID"
            ),
        ),
    ]
