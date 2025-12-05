# Generated migration for correcting indicator calculations

from django.db import migrations
from django.utils import timezone


def recalculate_all_indicators(apps, schema_editor):
    """
    Recalcula todos os indicadores em cache usando as fórmulas corretas.
    
    Mudanças implementadas:
    - TPS: Agora usa (Receitas - Despesas - Pagamentos Dívida) / Receitas × 100
    - RDR: Agora usa (Pagamentos Mensais Dívidas / Receitas) × 100 (ao invés de saldo total)
    - ILI: Mantém o cálculo (Reserva / Despesas Essenciais)
    """
    UserProfile = apps.get_model('finance', 'UserProfile')
    
    # Força invalidação de cache para todos os usuários
    # Os indicadores serão recalculados automaticamente no próximo acesso
    UserProfile.objects.all().update(
        indicators_updated_at=None,
        cached_tps=None,
        cached_rdr=None,
        cached_ili=None,
    )
    
    print(f"Cache de indicadores invalidado para {UserProfile.objects.count()} usuários.")
    print("Os indicadores serão recalculados com as novas fórmulas no próximo acesso.")


def reverse_recalculation(apps, schema_editor):
    """
    Reverse: também invalida cache para forçar recálculo com fórmulas antigas.
    """
    UserProfile = apps.get_model('finance', 'UserProfile')
    
    UserProfile.objects.all().update(
        indicators_updated_at=None,
        cached_tps=None,
        cached_rdr=None,
        cached_ili=None,
    )


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0015_fix_mission_progress_null_values'),
    ]

    operations = [
        migrations.RunPython(
            recalculate_all_indicators,
            reverse_recalculation,
        ),
    ]
