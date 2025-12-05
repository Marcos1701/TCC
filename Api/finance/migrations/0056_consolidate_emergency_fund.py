"""
Migration to consolidate EMERGENCY_FUND goals into SAVINGS.

This migration:
1. Updates all goals with goal_type='EMERGENCY_FUND' to goal_type='SAVINGS'
2. Is irreversible (cannot determine which goals were originally EMERGENCY_FUND after conversion)
"""

from django.db import migrations


def consolidate_emergency_fund_to_savings(apps, schema_editor):
    """Converts all EMERGENCY_FUND goals to SAVINGS."""
    Goal = apps.get_model('finance', 'Goal')
    count = Goal.objects.filter(goal_type='EMERGENCY_FUND').update(goal_type='SAVINGS')
    if count > 0:
        print(f'\n✅ Migrated {count} EMERGENCY_FUND goal(s) to SAVINGS')


def reverse_migration(apps, schema_editor):
    """
    Reversal is not possible - there's no way to identify which goals
    were originally EMERGENCY_FUND after the conversion.
    """
    print('\nWARNING: This migration cannot be reverted.')
    print('   EMERGENCY_FUND goals have already been converted to SAVINGS.')


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0055_goal_target_categories_m2m'),
    ]

    operations = [
        migrations.RunPython(
            consolidate_emergency_fund_to_savings,
            reverse_migration,
        ),
    ]
