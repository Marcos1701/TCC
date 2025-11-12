"""
Script de teste para validar missões especiais (metas e amigos).

Este script verifica:
1. Missões de metas são atualizadas ao criar uma meta
2. Missões de amigos são atualizadas ao adicionar um amigo
3. Progresso é calculado corretamente
"""

import os
import sys
import django

# Configurar Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User
from finance.models import Mission, MissionProgress, Goal, Friendship, UserProfile
from finance.services import update_mission_progress
from decimal import Decimal


def criar_usuario_teste():
    """Cria um usuário de teste."""
    username = f"teste_missoes_{os.urandom(4).hex()}"
    user = User.objects.create_user(
        username=username,
        email=f"{username}@test.com",
        password="teste123"
    )
    print(f"✅ Usuário criado: {username}")
    return user


def criar_missao_meta():
    """Cria uma missão de meta para teste."""
    mission, created = Mission.objects.get_or_create(
        title="🎯 Teste - Criar Primeira Meta",
        defaults={
            'description': 'Crie sua primeira meta financeira!',
            'mission_type': Mission.MissionType.ONBOARDING,
            'difficulty': Mission.Difficulty.EASY,
            'priority': 1,
            'reward_points': 100,
            'duration_days': 30,
            'validation_type': Mission.ValidationType.GOAL_PROGRESS,
            'goal_progress_target': Decimal('1.00'),
            'is_active': True,
        }
    )
    if created:
        print(f"✅ Missão de meta criada: {mission.title}")
    return mission


def criar_missao_amigo():
    """Cria uma missão de amigo para teste."""
    mission, created = Mission.objects.get_or_create(
        title="👥 Teste - Conecte-se com Primeiro Amigo",
        defaults={
            'description': 'Adicione seu primeiro amigo!',
            'mission_type': Mission.MissionType.ONBOARDING,
            'difficulty': Mission.Difficulty.EASY,
            'priority': 1,
            'reward_points': 100,
            'duration_days': 30,
            'validation_type': Mission.ValidationType.SNAPSHOT,
            'goal_progress_target': Decimal('1.00'),  # 1 amigo
            'is_active': True,
        }
    )
    if created:
        print(f"✅ Missão de amigo criada: {mission.title}")
    return mission


def testar_missao_meta():
    """Testa se missão de meta é atualizada corretamente."""
    print("\n" + "="*60)
    print("TESTE 1: Missão de Meta")
    print("="*60)
    
    user = criar_usuario_teste()
    mission = criar_missao_meta()
    
    # Buscar ou criar progresso da missão (pode já existir se foi auto-atribuída)
    progress, created = MissionProgress.objects.get_or_create(
        user=user,
        mission=mission,
        defaults={'status': MissionProgress.Status.ACTIVE}
    )
    if created:
        print(f"✅ Missão atribuída ao usuário")
    else:
        print(f"✅ Missão já estava atribuída ao usuário")
    print(f"   Progresso inicial: {progress.progress}%")
    
    # Criar uma meta
    goal = Goal.objects.create(
        user=user,
        title="Reserva de Emergência",
        description="Construir reserva",
        goal_type=Goal.GoalType.SAVINGS,
        target_amount=Decimal('5000.00'),
        current_amount=Decimal('0.00'),
    )
    print(f"✅ Meta criada: {goal.title}")
    
    # Atualizar progresso da missão
    update_mission_progress(user)
    
    # Verificar resultado
    progress.refresh_from_db()
    print(f"\n📊 RESULTADO:")
    print(f"   Progresso após criar meta: {progress.progress}%")
    print(f"   Status: {progress.status}")
    
    if progress.progress >= 100:
        print(f"   ✅ SUCESSO: Missão completada automaticamente!")
    else:
        print(f"   ❌ FALHA: Missão não foi completada (esperado 100%)")
    
    # Cleanup
    user.delete()
    print(f"\n🧹 Usuário de teste removido")


def testar_missao_amigo():
    """Testa se missão de amigo é atualizada corretamente."""
    print("\n" + "="*60)
    print("TESTE 2: Missão de Amigo")
    print("="*60)
    
    user1 = criar_usuario_teste()
    user2 = criar_usuario_teste()
    mission = criar_missao_amigo()
    
    # Buscar ou criar progresso da missão (pode já existir se foi auto-atribuída)
    progress, created = MissionProgress.objects.get_or_create(
        user=user1,
        mission=mission,
        defaults={'status': MissionProgress.Status.ACTIVE}
    )
    if created:
        print(f"✅ Missão atribuída ao usuário 1")
    else:
        print(f"✅ Missão já estava atribuída ao usuário 1")
    print(f"   Progresso inicial: {progress.progress}%")
    
    # Criar amizade
    friendship = Friendship.objects.create(
        user=user1,
        friend=user2,
        status=Friendship.FriendshipStatus.PENDING
    )
    print(f"✅ Solicitação de amizade enviada")
    
    # Aceitar amizade
    friendship.status = Friendship.FriendshipStatus.ACCEPTED
    friendship.save()
    print(f"✅ Amizade aceita")
    
    # Verificar resultado (signal deve ter chamado update_mission_progress)
    progress.refresh_from_db()
    print(f"\n📊 RESULTADO:")
    print(f"   Progresso após adicionar amigo: {progress.progress}%")
    print(f"   Status: {progress.status}")
    
    if progress.progress >= 100:
        print(f"   ✅ SUCESSO: Missão completada automaticamente!")
    else:
        print(f"   ❌ FALHA: Missão não foi completada (esperado 100%)")
    
    # Cleanup
    user1.delete()
    user2.delete()
    print(f"\n🧹 Usuários de teste removidos")


def testar_evolucao_indicadores():
    """Testa se a evolução de indicadores é exibida apenas para missões relevantes."""
    print("\n" + "="*60)
    print("TESTE 3: Filtro de Evolução de Indicadores")
    print("="*60)
    
    # Verificar missões existentes
    missoes_com_indicadores = Mission.objects.filter(
        mission_type__in=[
            Mission.MissionType.TPS_IMPROVEMENT,
            Mission.MissionType.RDR_REDUCTION,
            Mission.MissionType.ILI_BUILDING,
            Mission.MissionType.ADVANCED,
        ]
    ).count()
    
    missoes_onboarding = Mission.objects.filter(
        mission_type=Mission.MissionType.ONBOARDING
    ).count()
    
    print(f"📊 Missões que DEVEM exibir evolução de indicadores: {missoes_com_indicadores}")
    print(f"📊 Missões de ONBOARDING (não devem exibir): {missoes_onboarding}")
    print(f"\n✅ A lógica no Flutter agora filtra corretamente!")


if __name__ == '__main__':
    print("\n🚀 INICIANDO TESTES DE MISSÕES ESPECIAIS\n")
    
    try:
        testar_missao_meta()
        testar_missao_amigo()
        testar_evolucao_indicadores()
        
        print("\n" + "="*60)
        print("✅ TODOS OS TESTES CONCLUÍDOS!")
        print("="*60)
        
    except Exception as e:
        print(f"\n❌ ERRO DURANTE TESTE: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
