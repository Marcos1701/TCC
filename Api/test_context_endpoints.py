"""
Script para testar endpoints de contexto
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User
from finance.models import Mission, Category, Goal, Transaction, UserProfile
from finance.services import (
    analyze_user_context,
    identify_improvement_opportunities,
    calculate_mission_priorities,
    assign_missions_smartly
)
from datetime import datetime, timedelta
from decimal import Decimal


def setup_test_user():
    """Cria usuário de teste se não existir"""
    user, created = User.objects.get_or_create(
        username='test_context',
        defaults={
            'email': 'test@context.com',
            'first_name': 'Test',
            'last_name': 'Context'
        }
    )
    
    if created:
        user.set_password('testpass123')
        user.save()
        
        # Criar perfil
        UserProfile.objects.get_or_create(user=user)
        
        print(f"✅ Usuário de teste criado: {user.username}")
    else:
        print(f"ℹ️  Usando usuário existente: {user.username}")
    
    return user


def test_analyze_context():
    """Testa análise de contexto"""
    user = setup_test_user()
    
    print(f"\n📊 Analisando contexto do usuário {user.username}...")
    context = analyze_user_context(user)
    
    print(f"  - Categorias top: {len(context.get('top_spending_categories', []))}")
    print(f"  - Metas expirando: {len(context.get('expiring_goals', []))}")
    print(f"  - Indicadores em risco: {len(context.get('at_risk_indicators', []))}")
    print(f"  - Transações: {context.get('transaction_count', 0)}")
    print(f"  - Dias ativo: {context.get('days_active', 0)}")
    print(f"✅ Contexto analisado")
    
    return context


def test_identify_opportunities():
    """Testa identificação de oportunidades"""
    user = setup_test_user()
    
    print(f"\n🔍 Identificando oportunidades para {user.username}...")
    opportunities = identify_improvement_opportunities(user)
    
    print(f"  - Oportunidades encontradas: {len(opportunities)}")
    for opp in opportunities[:3]:
        print(f"    • {opp.get('type')}: {opp.get('priority')}")
    print(f"✅ Oportunidades identificadas")
    
    return opportunities


def test_calculate_priorities():
    """Testa cálculo de prioridades"""
    user = setup_test_user()
    
    print(f"\n⭐ Calculando prioridades para {user.username}...")
    missions_with_scores = calculate_mission_priorities(user)
    
    print(f"  - Missões avaliadas: {len(missions_with_scores)}")
    for mission, score in missions_with_scores[:3]:
        print(f"    • {mission.title}: {score:.2f}")
    print(f"✅ Prioridades calculadas")
    
    return missions_with_scores


def test_assign_missions():
    """Testa atribuição inteligente"""
    user = setup_test_user()
    
    print(f"\n🎯 Atribuindo missões para {user.username}...")
    assigned = assign_missions_smartly(user, max_active=3)
    
    print(f"  - Missões atribuídas: {len(assigned)}")
    for progress in assigned:
        print(f"    • {progress.mission.title}")
    print(f"✅ Missões atribuídas")
    
    return assigned


if __name__ == '__main__':
    print("=" * 60)
    print("TESTE DE ENDPOINTS DE CONTEXTO")
    print("=" * 60)
    
    context = test_analyze_context()
    opportunities = test_identify_opportunities()
    priorities = test_calculate_priorities()
    assigned = test_assign_missions()
    
    print("\n" + "=" * 60)
    print("RESUMO DOS TESTES")
    print("=" * 60)
    print(f"✅ Contexto: {len(context)} chaves retornadas")
    print(f"✅ Oportunidades: {len(opportunities)} identificadas")
    print(f"✅ Prioridades: {len(priorities)} missões avaliadas")
    print(f"✅ Atribuídas: {len(assigned)} missões")
    print("=" * 60)

