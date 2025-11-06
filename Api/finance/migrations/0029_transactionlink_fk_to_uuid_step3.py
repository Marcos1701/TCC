# Generated migration for TransactionLink FK to UUID - Step 3: Replace old FK with UUID FK

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0028_transactionlink_fk_to_uuid_step2'),
    ]

    operations = [
        # Step 3a: Remover as ForeignKeys antigas (que usam ID numérico)
        migrations.RemoveField(
            model_name='transactionlink',
            name='source_transaction',
        ),
        migrations.RemoveField(
            model_name='transactionlink',
            name='target_transaction',
        ),
        
        # Step 3b: Tornar campos temporários obrigatórios (não-null)
        # IMPORTANTE: Só execute isso se Step 2 populou TODOS os registros
        migrations.AlterField(
            model_name='transactionlink',
            name='source_transaction_uuid_temp',
            field=models.UUIDField(
                db_index=True,
                help_text="UUID da transação de origem"
            ),
        ),
        migrations.AlterField(
            model_name='transactionlink',
            name='target_transaction_uuid_temp',
            field=models.UUIDField(
                db_index=True,
                help_text="UUID da transação de destino"
            ),
        ),
        
        # Step 3c: Renomear campos temporários para nomes definitivos
        migrations.RenameField(
            model_name='transactionlink',
            old_name='source_transaction_uuid_temp',
            new_name='source_transaction_uuid',
        ),
        migrations.RenameField(
            model_name='transactionlink',
            old_name='target_transaction_uuid_temp',
            new_name='target_transaction_uuid',
        ),
        
        # Step 3d: Adicionar índices compostos para performance
        migrations.AddIndex(
            model_name='transactionlink',
            index=models.Index(
                fields=['user', 'source_transaction_uuid'],
                name='trl_user_src_uuid_idx'
            ),
        ),
        migrations.AddIndex(
            model_name='transactionlink',
            index=models.Index(
                fields=['user', 'target_transaction_uuid'],
                name='trl_user_tgt_uuid_idx'
            ),
        ),
    ]
