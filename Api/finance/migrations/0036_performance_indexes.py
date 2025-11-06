# Generated manually on 2025-11-06

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0035_remove_category_cat_user_type_sys_idx_and_more'),
    ]

    operations = [
        # Índice para dashboard queries (Transaction by user, date, type)
        migrations.AddIndex(
            model_name='transaction',
            index=models.Index(
                fields=['user', '-date', 'type'],
                name='tx_user_date_type_idx'
            ),
        ),
        
        # Índice para filtragem de links por tipo
        migrations.AddIndex(
            model_name='transactionlink',
            index=models.Index(
                fields=['user', 'link_type', '-created_at'],
                name='txlink_user_type_idx'
            ),
        ),
        
        # Índice para metas por usuário e deadline
        migrations.AddIndex(
            model_name='goal',
            index=models.Index(
                fields=['user', 'deadline', '-created_at'],
                name='goal_user_deadline_idx'
            ),
        ),
        
        # Índice para missões em progresso
        migrations.AddIndex(
            model_name='missionprogress',
            index=models.Index(
                fields=['user', 'status'],
                name='mission_user_status_idx'
            ),
        ),
        
        # Índice para transações por categoria e data (usado em relatórios)
        migrations.AddIndex(
            model_name='transaction',
            index=models.Index(
                fields=['user', 'category', '-date'],
                name='tx_user_cat_date_idx'
            ),
        ),
    ]
