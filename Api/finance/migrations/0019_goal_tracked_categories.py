# Generated migration for adding tracked_categories to Goal model

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0018_extend_goal_model'),
    ]

    operations = [
        migrations.AddField(
            model_name='goal',
            name='tracked_categories',
            field=models.ManyToManyField(
                blank=True,
                help_text='Categorias monitoradas para atualização automática (usado em metas como Juntar Dinheiro)',
                related_name='tracked_in_goals',
                to='finance.category'
            ),
        ),
        migrations.AlterField(
            model_name='goal',
            name='target_category',
            field=models.ForeignKey(
                blank=True,
                help_text='Categoria principal vinculada (para metas CATEGORY_* - retrocompatibilidade)',
                null=True,
                on_delete=models.deletion.SET_NULL,
                related_name='goals',
                to='finance.category'
            ),
        ),
    ]
