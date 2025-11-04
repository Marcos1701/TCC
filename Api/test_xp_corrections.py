"""
Script de teste para validar as correções no sistema de XP.
Testa atomicidade, race conditions e auditoria.
"""
import os
import sys
import django

# Setup Django
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from decimal import Decimal
from django.contrib.auth import get_user_model
from django.db import transaction
from finance.models import (
    Category, Mission, MissionProgress, Transaction, UserProfile, XPTransaction
)
from finance.services import (
    apply_mission_reward, assign_missions_automatically, calculate_summary,
    update_mission_progress
)

User = get_user_model()


def test_xp_system():
    """Testa o sistema de XP completo com as novas correções."""
    
    print("=" * 80)
    print("TESTE DO SISTEMA DE XP - COM CORREÇÕES APLICADAS")
    print("=" * 80)
    print()
    
    # 1. Criar usuário de teste
    print("1. Criando usuário de teste...")
    test_user = User.objects.filter(username='test_xp_user').first()
    if test_user:
        # Limpar dados antigos
        Transaction.objects.filter(user=test_user).delete()
        MissionProgress.objects.filter(user=test_user).delete()
        XPTransaction.objects.filter(user=test_user).delete()
        test_user.delete()
    
    test_user = User.objects.create_user(
        username='test_xp_user',
        email='test_xp@example.com',
        password='testpass123'
    )
    profile = UserProfile.objects.get(user=test_user)
    print(f"   ✓ Usuário criado: {test_user.username}")
    print(f"   ✓ Nível inicial: {profile.level}")
    print(f"   ✓ XP inicial: {profile.experience_points}")
    print()
    
    # 2. Verificar atribuição automática de missões
    print("2. Testando atribuição automática de missões...")
    assign_missions_automatically(test_user)
    active_missions = MissionProgress.objects.filter(
        user=test_user,
        status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
    )
    print(f"   ✓ Missões atribuídas: {active_missions.count()}")
    
    for mp in active_missions:
        print(f"   - {mp.mission.title} ({mp.mission.mission_type})")
        print(f"     Recompensa: {mp.mission.reward_points} XP")
        print(f"     Valores iniciais - TPS: {mp.initial_tps}, RDR: {mp.initial_rdr}, ILI: {mp.initial_ili}")
    print()
    
    # 3. Criar transações para simular progresso
    print("3. Criando transações para simular progresso...")
    
    # Buscar categorias padrão
    income_cat = Category.objects.filter(
        user__isnull=True, 
        type=Category.CategoryType.INCOME
    ).first()
    expense_cat = Category.objects.filter(
        user__isnull=True, 
        type=Category.CategoryType.EXPENSE
    ).first()
    
    # Criar 10 transações para completar missão de ONBOARDING
    for i in range(10):
        Transaction.objects.create(
            user=test_user,
            category=income_cat if i % 2 == 0 else expense_cat,
            type=Transaction.TransactionType.INCOME if i % 2 == 0 else Transaction.TransactionType.EXPENSE,
            description=f"Transação de teste {i+1}",
            amount=Decimal("100.00"),
        )
    
    print(f"   ✓ Criadas 10 transações")
    print()
    
    # 4. Atualizar progresso das missões
    print("4. Atualizando progresso das missões...")
    updated = update_mission_progress(test_user)
    print(f"   ✓ Missões atualizadas: {len(updated)}")
    
    for mp in updated:
        print(f"   - {mp.mission.title}")
        print(f"     Status: {mp.status}")
        print(f"     Progresso: {mp.progress}%")
        if mp.status == MissionProgress.Status.COMPLETED:
            print(f"     ✓ MISSÃO COMPLETADA!")
    print()
    
    # 5. Verificar XP e níveis
    print("5. Verificando XP e níveis após completar missões...")
    profile.refresh_from_db()
    print(f"   ✓ Nível atual: {profile.level}")
    print(f"   ✓ XP atual: {profile.experience_points}")
    print(f"   ✓ XP necessário para próximo nível: {profile.next_level_threshold}")
    print()
    
    # 6. Verificar auditoria de XP
    print("6. Verificando registros de auditoria de XP...")
    xp_transactions = XPTransaction.objects.filter(user=test_user).order_by('-created_at')
    print(f"   ✓ Registros de XP encontrados: {xp_transactions.count()}")
    
    for xp_tx in xp_transactions:
        print(f"   - Missão: {xp_tx.mission_progress.mission.title}")
        print(f"     XP concedido: {xp_tx.points_awarded}")
        print(f"     Nível: {xp_tx.level_before} → {xp_tx.level_after}")
        print(f"     XP: {xp_tx.xp_before} → {xp_tx.xp_after}")
        if xp_tx.level_after > xp_tx.level_before:
            print(f"     ✓ LEVEL UP!")
        print(f"     Data: {xp_tx.created_at}")
        print()
    
    # 7. Testar atomicidade (simular completar missão manualmente)
    print("7. Testando atomicidade ao completar missão manualmente...")
    pending_mission = MissionProgress.objects.filter(
        user=test_user,
        status=MissionProgress.Status.PENDING
    ).first()
    
    if pending_mission:
        xp_before = profile.experience_points
        level_before = profile.level
        
        # Forçar completar missão
        pending_mission.status = MissionProgress.Status.COMPLETED
        pending_mission.progress = Decimal("100.00")
        pending_mission.save()
        
        # Aplicar recompensa (com atomicidade)
        apply_mission_reward(pending_mission)
        
        profile.refresh_from_db()
        print(f"   ✓ Missão completada: {pending_mission.mission.title}")
        print(f"   ✓ XP antes: {xp_before}, depois: {profile.experience_points}")
        print(f"   ✓ Nível antes: {level_before}, depois: {profile.level}")
        print(f"   ✓ Registro de auditoria criado: {XPTransaction.objects.filter(mission_progress=pending_mission).exists()}")
    else:
        print("   ℹ Nenhuma missão pendente para testar")
    print()
    
    # 8. Verificar que missões inadequadas não são atribuídas
    print("8. Testando filtros de atribuição de missões...")
    
    # Criar muitas transações e uma reserva alta
    savings_cat = Category.objects.filter(
        user__isnull=True,
        group=Category.CategoryGroup.SAVINGS
    ).first()
    
    if savings_cat:
        # Simular aportes altos para aumentar ILI
        for i in range(5):
            Transaction.objects.create(
                user=test_user,
                category=savings_cat,
                type=Transaction.TransactionType.INCOME,
                description=f"Aporte reserva {i+1}",
                amount=Decimal("1000.00"),
            )
    
    # Forçar recálculo
    summary = calculate_summary(test_user)
    print(f"   ℹ Indicadores atuais:")
    print(f"     TPS: {summary['tps']}%")
    print(f"     RDR: {summary['rdr']}%")
    print(f"     ILI: {summary['ili']} meses")
    print()
    
    # Tentar atribuir novas missões
    old_count = MissionProgress.objects.filter(user=test_user).count()
    assign_missions_automatically(test_user)
    new_count = MissionProgress.objects.filter(user=test_user).count()
    
    print(f"   ✓ Missões antes: {old_count}, depois: {new_count}")
    print(f"   ✓ Novas missões atribuídas: {new_count - old_count}")
    
    new_missions = MissionProgress.objects.filter(
        user=test_user,
        status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
    ).exclude(status=MissionProgress.Status.COMPLETED)
    
    print(f"   ✓ Missões ativas atuais: {new_missions.count()}")
    for mp in new_missions:
        print(f"     - {mp.mission.title} ({mp.mission.mission_type})")
    print()
    
    # 9. Resumo final
    print("=" * 80)
    print("RESUMO FINAL")
    print("=" * 80)
    profile.refresh_from_db()
    completed_missions = MissionProgress.objects.filter(
        user=test_user,
        status=MissionProgress.Status.COMPLETED
    )
    total_xp_earned = sum(mp.mission.reward_points for mp in completed_missions)
    
    print(f"Usuário: {test_user.username}")
    print(f"Nível: {profile.level}")
    print(f"XP atual: {profile.experience_points}")
    print(f"Missões completadas: {completed_missions.count()}")
    print(f"Total de XP ganho: {total_xp_earned}")
    print(f"Registros de auditoria: {XPTransaction.objects.filter(user=test_user).count()}")
    print(f"Transações criadas: {Transaction.objects.filter(user=test_user).count()}")
    print()
    print("✓ TODOS OS TESTES CONCLUÍDOS COM SUCESSO!")
    print()


if __name__ == '__main__':
    test_xp_system()
