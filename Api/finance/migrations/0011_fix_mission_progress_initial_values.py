# Generated migration to fix mission progress initial values

from django.db import migrations
from decimal import Decimal


def fix_initial_values(apps, schema_editor):
    """
    Corrige valores iniciais None em MissionProgress existentes.
    """
    MissionProgress = apps.get_model('finance', 'MissionProgress')
    Transaction = apps.get_model('finance', 'Transaction')
    
    # Importar a função calculate_summary não funciona em migrations
    # Então vamos usar valores padrão razoáveis
    
    for progress in MissionProgress.objects.filter(
        initial_tps__isnull=True
    ) | MissionProgress.objects.filter(
        initial_rdr__isnull=True
    ) | MissionProgress.objects.filter(
        initial_ili__isnull=True
    ):
        # Definir valores padrão se None
        if progress.initial_tps is None:
            progress.initial_tps = Decimal('0.00')
        if progress.initial_rdr is None:
            progress.initial_rdr = Decimal('0.00')
        if progress.initial_ili is None:
            progress.initial_ili = Decimal('0.00')
        if progress.initial_transaction_count == 0:
            # Contar transações do usuário até a data de criação da missão
            count = Transaction.objects.filter(
                user=progress.user,
                created_at__lte=progress.updated_at
            ).count()
            progress.initial_transaction_count = max(1, count)
        
        progress.save(update_fields=[
            'initial_tps', 
            'initial_rdr', 
            'initial_ili', 
            'initial_transaction_count'
        ])


def reverse_fix(apps, schema_editor):
    """Reverse migration - não faz nada pois não queremos reverter correções."""
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0010_add_cached_totals'),
    ]

    operations = [
        migrations.RunPython(fix_initial_values, reverse_fix),
    ]
