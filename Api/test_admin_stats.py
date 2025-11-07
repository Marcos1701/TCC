"""
Script para testar o endpoint de estatísticas de admin.
Simula a chamada que o app faz e mostra o erro detalhado.
"""
import os
import sys
import django

# Configurar Django
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.models import User, UserProfile, Mission, MissionProgress
from django.db.models import Avg, Count

def test_admin_stats():
    """Testa as queries do endpoint de admin stats."""
    
    print("=" * 60)
    print("TESTE: Admin Stats Overview")
    print("=" * 60)
    
    try:
        # Total users
        print("\n1. Total de usuários...")
        total_users = User.objects.count()
        print(f"   ✓ Total: {total_users}")
        
        # Mission statistics
        print("\n2. Estatísticas de missões...")
        completed_missions = MissionProgress.objects.filter(
            status='COMPLETED'
        ).count()
        print(f"   ✓ Missões completadas: {completed_missions}")
        
        active_missions = Mission.objects.filter(
            is_active=True
        ).count()
        print(f"   ✓ Missões ativas: {active_missions}")
        
        # Average user level
        print("\n3. Nível médio dos usuários...")
        avg_level_data = UserProfile.objects.aggregate(
            avg_level=Avg('level')
        )
        avg_user_level = round(avg_level_data['avg_level'] or 0, 1)
        print(f"   ✓ Nível médio: {avg_user_level}")
        
        # Missions by difficulty
        print("\n4. Missões por dificuldade...")
        missions_by_difficulty = {}
        for difficulty in ['EASY', 'MEDIUM', 'HARD']:
            count = Mission.objects.filter(
                difficulty=difficulty,
                is_active=True
            ).count()
            missions_by_difficulty[difficulty] = count
            print(f"   ✓ {difficulty}: {count}")
        
        # Missions by type
        print("\n5. Missões por tipo...")
        missions_by_type = {}
        mission_types = ['ONBOARDING', 'TPS_IMPROVEMENT', 'RDR_REDUCTION', 'ILI_BUILDING', 'ADVANCED']
        for mission_type in mission_types:
            count = Mission.objects.filter(
                mission_type=mission_type,
                is_active=True
            ).count()
            missions_by_type[mission_type] = count
            print(f"   ✓ {mission_type}: {count}")
        
        # Recent activity
        print("\n6. Atividade recente...")
        recent_completions = MissionProgress.objects.filter(
            status='COMPLETED'
        ).select_related(
            'mission', 'user__profile'
        ).order_by('-updated_at')[:10]
        
        print(f"   ✓ {len(recent_completions)} completamentos recentes")
        
        # User level distribution
        print("\n7. Distribuição de níveis...")
        level_distribution = {
            '1-5': UserProfile.objects.filter(level__gte=1, level__lte=5).count(),
            '6-10': UserProfile.objects.filter(level__gte=6, level__lte=10).count(),
            '11-20': UserProfile.objects.filter(level__gte=11, level__lte=20).count(),
            '21+': UserProfile.objects.filter(level__gte=21).count(),
        }
        for range_name, count in level_distribution.items():
            print(f"   ✓ Níveis {range_name}: {count}")
        
        # Mission completion rate
        print("\n8. Taxa de conclusão...")
        total_mission_assignments = MissionProgress.objects.count()
        completion_rate = 0
        if total_mission_assignments > 0:
            completion_rate = round(
                (completed_missions / total_mission_assignments) * 100,
                1
            )
        print(f"   ✓ Taxa: {completion_rate}%")
        
        print("\n" + "=" * 60)
        print("✓ TODOS OS TESTES PASSARAM!")
        print("=" * 60)
        
        # Resumo final
        print("\nRESUMO DOS DADOS:")
        print(f"- Usuários: {total_users}")
        print(f"- Profiles: {UserProfile.objects.count()}")
        print(f"- Missões: {Mission.objects.count()}")
        print(f"- Progresso: {MissionProgress.objects.count()}")
        
        return True
        
    except Exception as e:
        print("\n" + "=" * 60)
        print("✗ ERRO ENCONTRADO!")
        print("=" * 60)
        print(f"\nTipo: {type(e).__name__}")
        print(f"Mensagem: {e}")
        
        import traceback
        print("\nStack trace completo:")
        traceback.print_exc()
        
        return False

if __name__ == '__main__':
    # Verificar se está usando banco de produção
    from django.conf import settings
    
    print("\nConfiguração do banco:")
    print(f"- ENGINE: {settings.DATABASES['default']['ENGINE']}")
    print(f"- NAME: {settings.DATABASES['default']['NAME']}")
    print(f"- HOST: {settings.DATABASES['default'].get('HOST', 'localhost')}")
    print()
    
    success = test_admin_stats()
    sys.exit(0 if success else 1)
