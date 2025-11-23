from django.db import migrations


def migrate_category_goals_to_custom(apps, schema_editor):
    Goal = apps.get_model('finance', 'Goal')
    
    updated_count = Goal.objects.filter(
        goal_type__in=['CATEGORY_EXPENSE', 'CATEGORY_INCOME']
    ).update(goal_type='CUSTOM')
    
    if updated_count > 0:
        print(f"Migrated {updated_count} goals from CATEGORY_* to CUSTOM")


class Migration(migrations.Migration):
    
    dependencies = [
        ('finance', '0040_remove_social_and_achievement_models'),
    ]
    
    operations = [
        migrations.RunPython(migrate_category_goals_to_custom, reverse_code=migrations.RunPython.noop),
        
        migrations.RemoveField(
            model_name='goal',
            name='target_category',
        ),
        migrations.RemoveField(
            model_name='goal',
            name='auto_update',
        ),
        migrations.RemoveField(
            model_name='goal',
            name='tracking_period',
        ),
        migrations.RemoveField(
            model_name='goal',
            name='is_reduction_goal',
        ),
        migrations.RemoveField(
            model_name='goal',
            name='tracked_categories',
        ),
    ]
