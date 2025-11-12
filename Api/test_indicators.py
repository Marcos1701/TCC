#!/usr/bin/env python
"""
Script de teste para verificar cálculo de indicadores e missões.
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User
from finance.models import Transaction, Goal, MissionProgress, Category
from finance.services import calculate_summary, update_mission_progress

def test_indicators():
    """Testa cálculo de indicadores."""
    print("=" * 80)
    print("TESTE DE INDICADORES")
    print("=" * 80)
    
    user = User.objects.first()
    if not user:
        print("❌ Nenhum usuário encontrado")
        return
    
    print(f"\n👤 Usuário: {user.username}")
    
    # Estatísticas de transações
    total_transactions = Transaction.objects.filter(user=user).count()
    income_count = Transaction.objects.filter(user=user, type='INCOME').count()
    expense_count = Transaction.objects.filter(user=user, type='EXPENSE').count()
    recurring_count = Transaction.objects.filter(user=user, is_recurring=True).count()
    
    print(f"\n📊 Transações:")
    print(f"   Total: {total_transactions}")
    print(f"   Receitas: {income_count}")
    print(f"   Despesas: {expense_count}")
    print(f"   Recorrentes: {recurring_count}")
    
    # Calcular indicadores
    summary = calculate_summary(user)
    
    print(f"\n💰 Indicadores:")
    print(f"   TPS (Taxa de Poupança): {summary['tps']}%")
    print(f"   RDR (Despesas Recorrentes): {summary['rdr']}%")
    print(f"   ILI (Reserva Emergência): {summary['ili']} meses")
    print(f"   Receita Total: R$ {summary['total_income']}")
    print(f"   Despesa Total: R$ {summary['total_expense']}")
    
    # Verificar missões
    print(f"\n🎯 Missões:")
    active_missions = MissionProgress.objects.filter(
        user=user,
        status__in=['PENDING', 'ACTIVE']
    )
    print(f"   Ativas: {active_missions.count()}")
    
    for mp in active_missions:
        print(f"   - {mp.mission.title}: {mp.progress}% ({mp.status})")
    
    # Verificar missão de criar meta
    goal_mission = MissionProgress.objects.filter(
        user=user,
        mission__validation_type='GOAL_PROGRESS',
        mission__target_goal__isnull=True
    ).first()
    
    if goal_mission:
        print(f"\n🎯 Missão 'Primeira Meta':")
        print(f"   Status: {goal_mission.status}")
        print(f"   Progresso: {goal_mission.progress}%")
        print(f"   Target: {goal_mission.mission.goal_progress_target}")
        
        goals_count = Goal.objects.filter(user=user).count()
        print(f"   Metas criadas: {goals_count}")
    
    print("\n✅ Teste concluído")

if __name__ == '__main__':
    test_indicators()
