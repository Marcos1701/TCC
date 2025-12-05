"""
Migration to remove EMERGENCY_FUND from goal_type choices.

This migration:
1. Updates the goal_type field choices to remove EMERGENCY_FUND
2. Assumes all EMERGENCY_FUND goals have already been migrated to SAVINGS (migration 0056)

NOTE: This is a safe migration - it only changes the field choices, not the data.
"""

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0056_consolidate_emergency_fund'),
    ]

    operations = [
        migrations.AlterField(
            model_name='goal',
            name='goal_type',
            field=models.CharField(
                choices=[
                    ('SAVINGS', 'Juntar Dinheiro'),
                    ('EXPENSE_REDUCTION', 'Reduzir Gastos'),
                    ('INCOME_INCREASE', 'Aumentar Receita'),
                    ('CUSTOM', 'Personalizada'),
                ],
                default='CUSTOM',
                help_text='Tipo da meta',
                max_length=20,
            ),
        ),
    ]
