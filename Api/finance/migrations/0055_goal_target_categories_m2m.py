# Generated manually for target_category -> target_categories migration

from django.db import migrations, models


def forward_migrate_categories(apps, schema_editor):
    """Migra dados de target_category (FK) para target_categories (M2M)."""
    Goal = apps.get_model('finance', 'Goal')
    
    for goal in Goal.objects.filter(target_category__isnull=False):
        # Adiciona a categoria antiga ao novo M2M
        goal.target_categories.add(goal.target_category)


def backward_migrate_categories(apps, schema_editor):
    """Reverte: pega a primeira categoria do M2M e coloca no FK."""
    Goal = apps.get_model('finance', 'Goal')
    
    for goal in Goal.objects.all():
        first_cat = goal.target_categories.first()
        if first_cat:
            goal.target_category = first_cat
            goal.save(update_fields=['target_category'])


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0054_remove_transaction_tx_user_type_date_idx_and_more'),
    ]

    operations = [
        # Passo 1: Criar o campo ManyToMany
        migrations.AddField(
            model_name='goal',
            name='target_categories',
            field=models.ManyToManyField(
                blank=True,
                help_text='Categorias alvo para metas de redução de gastos (máximo 5)',
                related_name='goals_targeting_this_new',  # Temporário
                to='finance.category',
            ),
        ),
        
        # Passo 2: Migrar dados
        migrations.RunPython(forward_migrate_categories, backward_migrate_categories),
        
        # Passo 3: Remover o campo FK antigo
        migrations.RemoveField(
            model_name='goal',
            name='target_category',
        ),
        
        # Passo 4: Renomear related_name para o correto
        migrations.AlterField(
            model_name='goal',
            name='target_categories',
            field=models.ManyToManyField(
                blank=True,
                help_text='Categorias alvo para metas de redução de gastos (máximo 5)',
                related_name='goals_targeting_this',
                to='finance.category',
            ),
        ),
    ]
