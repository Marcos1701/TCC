# Generated migration to simplify mission system
# - Removes TEMPORAL from ValidationType choices
# - Migrates any existing TEMPORAL missions to INDICATOR_THRESHOLD
# - Marks deprecated fields for future removal

from django.db import migrations, models


def migrate_temporal_to_indicator(apps, schema_editor):
    """Convert any TEMPORAL validation type to INDICATOR_THRESHOLD."""
    Mission = apps.get_model('finance', 'Mission')
    
    # Update any missions with TEMPORAL validation_type
    updated_count = Mission.objects.filter(validation_type='TEMPORAL').update(
        validation_type='INDICATOR_THRESHOLD'
    )
    
    if updated_count > 0:
        print(f"\n  Migrated {updated_count} missions from TEMPORAL to INDICATOR_THRESHOLD")


def reverse_migration(apps, schema_editor):
    """Reverse migration - no action needed as we're simplifying."""
    pass


class Migration(migrations.Migration):
    
    dependencies = [
        ('finance', '0058_remove_goals'),
    ]
    
    operations = [
        # First, migrate any existing TEMPORAL data
        migrations.RunPython(
            migrate_temporal_to_indicator,
            reverse_migration,
        ),
        
        # Update validation_type choices to remove TEMPORAL
        migrations.AlterField(
            model_name='mission',
            name='validation_type',
            field=models.CharField(
                choices=[
                    ('TRANSACTION_COUNT', 'Registrar X Transações'),
                    ('INDICATOR_THRESHOLD', 'Atingir Valor de Indicador'),
                    ('CATEGORY_REDUCTION', 'Reduzir % em Categoria'),
                    # TEMPORAL removed - simplified logic
                ],
                default='TRANSACTION_COUNT',
                help_text='Tipo de validação que determina como o progresso é calculado',
                max_length=35,
            ),
        ),
    ]
