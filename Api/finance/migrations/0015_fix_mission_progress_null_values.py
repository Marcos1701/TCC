# Generated manually to fix None values in MissionProgress
from decimal import Decimal
from django.db import migrations


def fix_null_initial_values(apps, schema_editor):
    """
    Corrige valores None em campos initial_* de MissionProgress.
    Missões ativas sem valores iniciais recebem 0 como padrão.
    """
    MissionProgress = apps.get_model("finance", "MissionProgress")
    
    # Contar quantas missões serão atualizadas
    missions_to_fix = MissionProgress.objects.filter(
        status__in=['PENDING', 'ACTIVE']
    ).filter(
        initial_tps__isnull=True
    ) | MissionProgress.objects.filter(
        status__in=['PENDING', 'ACTIVE']
    ).filter(
        initial_rdr__isnull=True
    ) | MissionProgress.objects.filter(
        status__in=['PENDING', 'ACTIVE']
    ).filter(
        initial_ili__isnull=True
    )
    
    count = missions_to_fix.distinct().count()
    if count > 0:
        print(f"Corrigindo {count} missão(ões) com valores iniciais None...")
    
    # Atualizar valores None para 0
    MissionProgress.objects.filter(
        status__in=['PENDING', 'ACTIVE'],
        initial_tps__isnull=True
    ).update(initial_tps=Decimal('0.00'))
    
    MissionProgress.objects.filter(
        status__in=['PENDING', 'ACTIVE'],
        initial_rdr__isnull=True
    ).update(initial_rdr=Decimal('0.00'))
    
    MissionProgress.objects.filter(
        status__in=['PENDING', 'ACTIVE'],
        initial_ili__isnull=True
    ).update(initial_ili=Decimal('0.00'))
    
    MissionProgress.objects.filter(
        status__in=['PENDING', 'ACTIVE'],
        initial_transaction_count=0
    ).update(initial_transaction_count=1)
    
    if count > 0:
        print(f"Valores iniciais corrigidos com sucesso!")


def reverse_fix(apps, schema_editor):
    """
    Não há necessidade de reverter - valores 0 são válidos.
    """
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0014_add_xp_transaction_audit"),
    ]

    operations = [
        migrations.RunPython(fix_null_initial_values, reverse_fix),
    ]
