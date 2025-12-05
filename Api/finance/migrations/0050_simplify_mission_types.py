"""
Migração para simplificar o sistema de missões.

Remove todas as missões existentes e atualiza os tipos para o sistema simplificado:
- 6 MissionTypes: ONBOARDING, TPS_IMPROVEMENT, RDR_REDUCTION, ILI_BUILDING, CATEGORY_REDUCTION, GOAL_ACHIEVEMENT
- 5 ValidationTypes: TRANSACTION_COUNT, INDICATOR_THRESHOLD, CATEGORY_REDUCTION, GOAL_PROGRESS, TEMPORAL

Esta migração:
1. Remove todas as missões existentes (Mission e MissionProgress)
2. Atualiza as choices do campo mission_type
3. Atualiza as choices do campo validation_type
"""

from django.db import migrations, models


def clear_missions(apps, schema_editor):
    """Remove todas as missões e progressos existentes."""
    Mission = apps.get_model('finance', 'Mission')
    MissionProgress = apps.get_model('finance', 'MissionProgress')
    
    # Primeiro remove os progressos (dependem das missões)
    progress_count = MissionProgress.objects.count()
    MissionProgress.objects.all().delete()
    
    # Depois remove as missões
    mission_count = Mission.objects.count()
    Mission.objects.all().delete()
    
    print(f"\nRemovidas {mission_count} missões e {progress_count} progressos.")


def reverse_clear(apps, schema_editor):
    """Reversão não restaura dados deletados."""
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0049_remove_snapshot_tables'),
    ]

    operations = [
        # 1. Limpar dados existentes
        migrations.RunPython(clear_missions, reverse_clear),
        
        # 2. Atualizar campo mission_type com novos choices
        migrations.AlterField(
            model_name='mission',
            name='mission_type',
            field=models.CharField(
                choices=[
                    ('ONBOARDING', 'Primeiros Passos'),
                    ('TPS_IMPROVEMENT', 'Aumentar Poupança (TPS)'),
                    ('RDR_REDUCTION', 'Reduzir Gastos Recorrentes (RDR)'),
                    ('ILI_BUILDING', 'Construir Reserva (ILI)'),
                    ('CATEGORY_REDUCTION', 'Reduzir Gastos em Categoria'),
                    ('GOAL_ACHIEVEMENT', 'Progredir em Meta'),
                ],
                default='ONBOARDING',
                help_text='Tipo de missão que determina quando será aplicada',
                max_length=30,
            ),
        ),
        
        # 3. Atualizar campo validation_type com novos choices
        migrations.AlterField(
            model_name='mission',
            name='validation_type',
            field=models.CharField(
                choices=[
                    ('TRANSACTION_COUNT', 'Registrar X Transações'),
                    ('INDICATOR_THRESHOLD', 'Atingir Valor de Indicador'),
                    ('CATEGORY_REDUCTION', 'Reduzir % em Categoria'),
                    ('GOAL_PROGRESS', 'Atingir % de Progresso em Meta'),
                    ('TEMPORAL', 'Manter Critério por Período'),
                ],
                default='TRANSACTION_COUNT',
                help_text='Tipo de validação que determina como o progresso é calculado',
                max_length=35,
            ),
        ),
    ]
