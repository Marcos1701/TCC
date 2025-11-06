# Safe migration: Convert UUID to Primary Key without data loss
# Strategy: Rename uuid→id after removing the auto-generated id field

from django.db import migrations, models
import uuid


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0029_transactionlink_fk_to_uuid_step3'),
    ]

    operations = [
        # ==== STEP 1: Remove old auto-increment ID fields ====
        migrations.RemoveField(
            model_name='transaction',
            name='id',
        ),
        migrations.RemoveField(
            model_name='goal',
            name='id',
        ),
        migrations.RemoveField(
            model_name='transactionlink',
            name='id',
        ),
        migrations.RemoveField(
            model_name='friendship',
            name='id',
        ),
        
        # ==== STEP 2: Rename uuid→id and make it primary key ====
        migrations.RenameField(
            model_name='transaction',
            old_name='uuid',
            new_name='id',
        ),
        migrations.RenameField(
            model_name='goal',
            old_name='uuid',
            new_name='id',
        ),
        migrations.RenameField(
            model_name='transactionlink',
            old_name='uuid',
            new_name='id',
        ),
        migrations.RenameField(
            model_name='friendship',
            old_name='uuid',
            new_name='id',
        ),
        
        # ==== STEP 3: Alter fields to be primary keys ====
        migrations.AlterField(
            model_name='transaction',
            name='id',
            field=models.UUIDField(
                default=uuid.uuid4,
                primary_key=True,
                editable=False,
                serialize=False,
                help_text='Identificador único universal (UUID v4)'
            ),
        ),
        migrations.AlterField(
            model_name='goal',
            name='id',
            field=models.UUIDField(
                default=uuid.uuid4,
                primary_key=True,
                editable=False,
                serialize=False,
                help_text='Identificador único universal (UUID v4)'
            ),
        ),
        migrations.AlterField(
            model_name='transactionlink',
            name='id',
            field=models.UUIDField(
                default=uuid.uuid4,
                primary_key=True,
                editable=False,
                serialize=False,
                help_text='Identificador único universal (UUID v4)'
            ),
        ),
        migrations.AlterField(
            model_name='friendship',
            name='id',
            field=models.UUIDField(
                default=uuid.uuid4,
                primary_key=True,
                editable=False,
                serialize=False,
                help_text='Identificador único universal (UUID v4)'
            ),
        ),
        
        # ==== STEP 4: Update indexes on TransactionLink ====
        migrations.RemoveIndex(
            model_name='transactionlink',
            name='finance_tra_source__31780a_idx',
        ),
        migrations.RemoveIndex(
            model_name='transactionlink',
            name='finance_tra_target__b63973_idx',
        ),
        migrations.AddIndex(
            model_name='transactionlink',
            index=models.Index(fields=['source_transaction_uuid'], name='finance_tra_source__4fb083_idx'),
        ),
        migrations.AddIndex(
            model_name='transactionlink',
            index=models.Index(fields=['target_transaction_uuid'], name='finance_tra_target__2b7f07_idx'),
        ),
    ]
