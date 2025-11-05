# Generated migration for adding security improvements

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0023_set_existing_users_not_first_access'),
    ]

    operations = [
        # Adicionar índice composto otimizado para queries de listagem
        migrations.AddIndex(
            model_name='transaction',
            index=models.Index(
                fields=['user', '-date', '-created_at'],
                name='finance_tra_user_da_idx'
            ),
        ),
        
        # Constraint: valores de transação devem ser positivos
        migrations.AddConstraint(
            model_name='transaction',
            constraint=models.CheckConstraint(
                check=models.Q(amount__gt=0),
                name='transaction_amount_positive'
            ),
        ),
        
        # Constraint: transações recorrentes devem ter valor e unidade
        migrations.AddConstraint(
            model_name='transaction',
            constraint=models.CheckConstraint(
                check=(
                    models.Q(is_recurring=False) |
                    (
                        models.Q(is_recurring=True) &
                        models.Q(recurrence_value__isnull=False) &
                        models.Q(recurrence_unit__isnull=False)
                    )
                ),
                name='transaction_recurrence_fields_required'
            ),
        ),
        
        # Constraint: valores de Goal devem ser positivos
        migrations.AddConstraint(
            model_name='goal',
            constraint=models.CheckConstraint(
                check=models.Q(target_amount__gt=0),
                name='goal_target_amount_positive'
            ),
        ),
        
        # Constraint: current_amount não pode ser negativo
        migrations.AddConstraint(
            model_name='goal',
            constraint=models.CheckConstraint(
                check=models.Q(current_amount__gte=0),
                name='goal_current_amount_non_negative'
            ),
        ),
        
        # Nota: TransactionLink já tem constraint linked_amount_positive no modelo
        # Não precisa ser adicionado aqui
    ]
