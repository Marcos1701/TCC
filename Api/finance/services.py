from __future__ import annotations

import logging
from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Any, Dict, Iterable, List, Tuple
from dateutil.relativedelta import relativedelta

from django.db.models import Avg, Case, Count, DecimalField, F, Max, Min, Q, Sum, When, Value
from django.db.models.functions import Coalesce, TruncMonth
from django.utils import timezone

from .models import Category, Goal, Mission, MissionProgress, Transaction, UserProfile

logger = logging.getLogger(__name__)


# ============================================================================
# ANÁLISE CONTEXTUAL BASEADA EM REGRAS
# ============================================================================

def analyze_user_context(user) -> Dict[str, Any]:
    """Analisa contexto financeiro com regras determinísticas."""
    today = timezone.now().date()
    thirty_days_ago = today - timedelta(days=30)
    
    recent_transactions = Transaction.objects.filter(
        user=user,
        date__gte=thirty_days_ago
    ).select_related('category').order_by('-date')
    
    transaction_count = Transaction.objects.filter(user=user).count()
    
    top_spending = Transaction.objects.filter(
        user=user,
        type=Transaction.TransactionType.EXPENSE
    ).values('category__name', 'category__id').annotate(
        total=Sum('amount')
    ).order_by('-total')[:5]
    
    top_categories = [
        {
            'category_id': item['category__id'],
            'category_name': item['category__name'],
            'total_spent': float(item['total'])
        }
        for item in top_spending
    ]
    
    thirty_days_future = today + timedelta(days=30)
    expiring_goals = Goal.objects.filter(
        user=user,
        deadline__lte=thirty_days_future,
        deadline__gte=today
    ).exclude(
        current_amount__gte=F('target_amount')  # Excluir já completadas
    ).order_by('deadline')
    
    goals_data = [
        {
            'id': goal.id,
            'name': goal.title,
            'target_date': goal.deadline.isoformat(),
            'progress_percentage': float((goal.current_amount / goal.target_amount * 100) if goal.target_amount > 0 else 0),
            'days_remaining': (goal.deadline - today).days
        }
        for goal in expiring_goals
    ]
    
    summary = calculate_summary(user)
    profile, _ = UserProfile.objects.get_or_create(user=user)
    
    at_risk_indicators = []
    
    tps = float(summary.get('tps', Decimal('0')))
    if tps < profile.target_tps:
        at_risk_indicators.append({
            'indicator': 'TPS',
            'current': tps,
            'target': profile.target_tps,
            'gap': profile.target_tps - tps
        })
    
    rdr = float(summary.get('rdr', Decimal('0')))
    if rdr > profile.target_rdr:
        at_risk_indicators.append({
            'indicator': 'RDR',
            'current': rdr,
            'target': profile.target_rdr,
            'gap': rdr - profile.target_rdr
        })
    
    ili = float(summary.get('ili', Decimal('0')))
    target_ili = float(profile.target_ili)
    if ili < target_ili:
        at_risk_indicators.append({
            'indicator': 'ILI',
            'current': ili,
            'target': target_ili,
            'gap': target_ili - ili
        })
    
    spending_patterns = Transaction.objects.filter(
        user=user,
        type=Transaction.TransactionType.EXPENSE,
        date__gte=thirty_days_ago
    ).values('category__name').annotate(
        count=Count('id'),
        avg_amount=Avg('amount')
    ).order_by('-count')[:5]
    
    patterns_data = [
        {
            'category': item['category__name'],
            'frequency': item['count'],
            'avg_amount': float(item['avg_amount'])
        }
        for item in spending_patterns
    ]
    
    first_transaction = Transaction.objects.filter(user=user).order_by('date').first()
    days_active = (today - first_transaction.date).days if first_transaction else 0
    
    recent_trans_data = [
        {
            'id': trans.id,
            'amount': float(trans.amount),
            'category': trans.category.name if trans.category else 'Sem Categoria',
            'date': trans.date.isoformat(),
            'description': trans.description
        }
        for trans in recent_transactions[:10]
    ]
    
    return {
        'top_spending_categories': top_categories,
        'expiring_goals': goals_data,
        'at_risk_indicators': at_risk_indicators,
        'spending_patterns': patterns_data,
        'recent_transactions': recent_trans_data,
        'transaction_count': transaction_count,
        'days_active': days_active,
        'summary': {
            'tps': float(summary.get('tps', Decimal('0'))),
            'rdr': float(summary.get('rdr', Decimal('0'))),
            'ili': float(summary.get('ili', Decimal('0'))),
        }
    }


def identify_improvement_opportunities(user) -> List[Dict[str, Any]]:
    """Identifica oportunidades de melhoria por padrões de gastos e indicadores."""
    opportunities = []
    today = timezone.now().date()
    
    thirty_days_ago = today - timedelta(days=30)
    sixty_days_ago = today - timedelta(days=60)
    
    # Gasto últimos 30 dias por categoria
    recent_spending = Transaction.objects.filter(
        user=user,
        type=Transaction.TransactionType.EXPENSE,
        date__gte=thirty_days_ago
    ).values('category__id', 'category__name').annotate(
        total=Sum('amount')
    )
    
    # Gasto 30-60 dias atrás por categoria
    previous_spending = Transaction.objects.filter(
        user=user,
        type=Transaction.TransactionType.EXPENSE,
        date__gte=sixty_days_ago,
        date__lt=thirty_days_ago
    ).values('category__id', 'category__name').annotate(
        total=Sum('amount')
    )
    
    # Criar dict para comparação
    recent_dict = {item['category__id']: float(item['total']) for item in recent_spending}
    previous_dict = {item['category__id']: float(item['total']) for item in previous_spending}
    
    for cat_id, recent_total in recent_dict.items():
        previous_total = previous_dict.get(cat_id, 0)
        if previous_total > 0:
            growth_percent = ((recent_total - previous_total) / previous_total) * 100
            if growth_percent > 20:  # Crescimento de 20%+
                category_name = next(
                    (item['category__name'] for item in recent_spending if item['category__id'] == cat_id),
                    'Desconhecida'
                )
                opportunities.append({
                    'type': 'CATEGORY_GROWTH',
                    'priority': 'HIGH' if growth_percent > 50 else 'MEDIUM',
                    'description': f'Gasto em "{category_name}" cresceu {growth_percent:.1f}%',
                    'data': {
                        'category_id': cat_id,
                        'category_name': category_name,
                        'growth_percent': growth_percent,
                        'recent_total': recent_total,
                        'previous_total': previous_total
                    }
                })
    
    # 2. Metas estagnadas (sem transações há 15+ dias)
    fifteen_days_ago = today - timedelta(days=15)
    
    active_goals = Goal.objects.filter(
        user=user,
        deadline__gte=today  # Não vencidas
    ).exclude(
        current_amount__gte=F('target_amount')  # Não completadas
    )
    
    for goal in active_goals:
        # Verificar última transação relacionada à meta
        # Se a meta tiver categoria, verificar transações nela
        if goal.target_category:
            last_contribution = Transaction.objects.filter(
                user=user,
                category=goal.target_category,
                type=Transaction.TransactionType.INCOME
            ).order_by('-date').first()
        else:
            # Para metas sem categoria específica, pular verificação
            continue
        
        if not last_contribution or last_contribution.date < fifteen_days_ago:
            days_stagnant = (today - last_contribution.date).days if last_contribution else 999
            opportunities.append({
                'type': 'GOAL_STAGNANT',
                'priority': 'HIGH' if days_stagnant > 30 else 'MEDIUM',
                'description': f'Meta "{goal.title}" sem progresso há {days_stagnant} dias',
                'data': {
                    'goal_id': goal.id,
                    'goal_name': goal.title,
                    'days_stagnant': days_stagnant,
                    'progress_percent': float((goal.current_amount / goal.target_amount * 100) if goal.target_amount > 0 else 0)
                }
            })
    
    # 3. Indicadores em declínio
    # Comparar indicadores atuais com período anterior
    summary_current = calculate_summary(user)
    
    # Calcular indicadores de 30 dias atrás (estimativa simples)
    # Para simplificar, verificamos apenas se estão abaixo das metas
    profile, _ = UserProfile.objects.get_or_create(user=user)
    
    tps = float(summary_current.get('tps', Decimal('0')))
    if tps < profile.target_tps:
        gap = profile.target_tps - tps
        opportunities.append({
            'type': 'INDICATOR_BELOW_TARGET',
            'priority': 'HIGH' if gap > 10 else 'MEDIUM',
            'description': f'TPS abaixo da meta: {tps:.1f}% (meta: {profile.target_tps}%)',
            'data': {
                'indicator': 'TPS',
                'current': tps,
                'target': profile.target_tps,
                'gap': gap
            }
        })
    
    rdr = float(summary_current.get('rdr', Decimal('0')))
    if rdr > profile.target_rdr:
        gap = rdr - profile.target_rdr
        opportunities.append({
            'type': 'INDICATOR_ABOVE_TARGET',
            'priority': 'HIGH' if gap > 20 else 'MEDIUM',
            'description': f'RDR acima da meta: {rdr:.1f}% (meta: {profile.target_rdr}%)',
            'data': {
                'indicator': 'RDR',
                'current': rdr,
                'target': profile.target_rdr,
                'gap': gap
            }
        })
    
    ili = float(summary_current.get('ili', Decimal('0')))
    target_ili = float(profile.target_ili)
    if ili < target_ili:
        gap = target_ili - ili
        opportunities.append({
            'type': 'INDICATOR_BELOW_TARGET',
            'priority': 'HIGH' if gap > 3 else 'MEDIUM',
            'description': f'ILI abaixo da meta: {ili:.1f} meses (meta: {target_ili:.1f})',
            'data': {
                'indicator': 'ILI',
                'current': ili,
                'target': target_ili,
                'gap': gap
            }
        })
    
    # Ordenar por prioridade
    priority_order = {'HIGH': 0, 'MEDIUM': 1, 'LOW': 2}
    opportunities.sort(key=lambda x: priority_order.get(x['priority'], 3))
    
    return opportunities


def assign_missions_smartly(user, max_active: int = 3) -> List[MissionProgress]:
    """Atribui missões inteligentemente baseado em análise contextual (até max_active missões)."""
    existing_progress = MissionProgress.objects.filter(user=user)
    active_missions = existing_progress.filter(
        status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
    )
    
    active_count = active_missions.count()
    
    # Se já tem o máximo de missões ativas, retornar as existentes
    if active_count >= max_active:
        return list(active_missions)
    
    # Calcular quantas missões novas podem ser atribuídas
    slots_available = max_active - active_count
    
    # Analisar contexto do usuário
    context = analyze_user_context(user)
    
    # Calcular prioridades de todas as missões disponíveis
    mission_priorities = calculate_mission_priorities(user, context)
    
    # Filtrar missões que já estão ativas ou atribuídas
    already_assigned_ids = set(existing_progress.values_list('mission_id', flat=True))
    available_with_priority = [
        (mission, score) for mission, score in mission_priorities 
        if mission.id not in already_assigned_ids and score > 0
    ]
    
    # Evitar missões muito similares (mesmo tipo)
    selected_missions = []
    selected_types = set(active_missions.values_list('mission__mission_type', flat=True))
    
    for mission, score in available_with_priority:
        if len(selected_missions) >= slots_available:
            break
        
        # Se já tem missão do mesmo tipo, penalizar (mas não bloquear completamente)
        if mission.mission_type in selected_types:
            # Só adiciona se score for muito alto (>70)
            if score < 70:
                continue
        
        selected_missions.append(mission)
        selected_types.add(mission.mission_type)
    
    # Criar MissionProgress para as novas missões
    new_progress_list = []
    for mission in selected_missions:
        progress, created = MissionProgress.objects.get_or_create(
            user=user,
            mission=mission,
            defaults={
                'status': MissionProgress.Status.PENDING,
            }
        )
        new_progress_list.append(progress)
    
    # Retornar todas as missões ativas (antigas + novas)
    all_active = list(active_missions) + new_progress_list
    return all_active


def calculate_mission_priorities(user, context: Dict[str, Any] = None) -> List[Tuple[Mission, float]]:
    """Calcula score de prioridade de missões baseado em contexto e oportunidades."""
    if context is None:
        context = analyze_user_context(user)
    
    opportunities = identify_improvement_opportunities(user)
    at_risk = context.get('at_risk_indicators', [])
    
    # Buscar missões ativas não já atribuídas
    already_assigned = MissionProgress.objects.filter(user=user).values_list('mission_id', flat=True)
    available_missions = Mission.objects.filter(
        is_active=True
    ).exclude(id__in=already_assigned)
    
    mission_scores = []
    
    for mission in available_missions:
        score = 0.0
        
        # 1. Alinhamento com indicadores em risco (40 pontos máximo)
        for indicator_data in at_risk:
            indicator = indicator_data['indicator']
            if indicator == 'TPS' and mission.mission_type in ['TPS_IMPROVEMENT', 'SAVINGS_STREAK', 'INCOME_TRACKING']:
                score += 40
                break
            elif indicator == 'RDR' and mission.mission_type in ['RDR_REDUCTION', 'CATEGORY_REDUCTION', 'EXPENSE_CONTROL']:
                score += 40
                break
            elif indicator == 'ILI' and mission.mission_type in ['ILI_BUILDING', 'GOAL_ACHIEVEMENT', 'WEALTH_BUILDING']:
                score += 40
                break
        
        # 2. Alinhamento com oportunidades (30 pontos máximo)
        for opp in opportunities:
            if opp['type'] == 'CATEGORY_GROWTH' and mission.mission_type in ['CATEGORY_REDUCTION', 'CATEGORY_SPENDING_LIMIT']:
                # Verificar se categoria coincide
                if mission.target_category and mission.target_category.id == opp['data'].get('category_id'):
                    score += 30
                else:
                    score += 15
            elif opp['type'] == 'GOAL_STAGNANT' and mission.mission_type in ['GOAL_ACHIEVEMENT', 'GOAL_CONSISTENCY']:
                if mission.target_goal and mission.target_goal.id == opp['data'].get('goal_id'):
                    score += 30
                else:
                    score += 15
        
        # 3. Relação dificuldade/recompensa (20 pontos máximo)
        difficulty_multiplier = {
            'EASY': 1.0,
            'MEDIUM': 0.7,
            'HARD': 0.4
        }
        reward_points = mission.reward_points or 50
        difficulty_factor = difficulty_multiplier.get(mission.difficulty, 0.7)
        score += (reward_points / 100) * difficulty_factor * 20
        
        # 4. Prioridade da missão (10 pontos máximo)
        # Missões com prioridade 1 = 10 pontos, prioridade 10 = 1 ponto
        priority_score = max(0, 11 - mission.priority)
        score += priority_score
        
        # 5. Adequação ao perfil do usuário
        transaction_count = context.get('transaction_count', 0)
        if mission.min_transactions and transaction_count < mission.min_transactions:
            score *= 0.1  # Penalizar fortemente se não tem transações mínimas
        
        # Verificar limites de indicadores
        summary = context.get('summary', {})
        tps = summary.get('tps', 0)
        rdr = summary.get('rdr', 0)
        ili = summary.get('ili', 0)
        
        if mission.target_tps and tps < mission.target_tps:
            score *= 0.5
        if mission.target_rdr and rdr > mission.target_rdr:
            score *= 0.5
        if mission.min_ili and ili < float(mission.min_ili):
            score *= 0.5
        if mission.max_ili and ili > float(mission.max_ili):
            score *= 0.5
        
        mission_scores.append((mission, score))
    
    # Ordenar por score decrescente
    mission_scores.sort(key=lambda x: x[1], reverse=True)
    
    return mission_scores


def _decimal(value) -> Decimal:
    """Converte um valor para Decimal, retornando 0 se None."""
    if isinstance(value, Decimal):
        return value
    return Decimal(value or 0)



def calculate_summary(user) -> Dict[str, Decimal]:
    """
    Calcula indicadores financeiros de um usuário.
    Utiliza cache quando disponível e não expirado.
    
    Indicadores calculados:
    - TPS (Taxa de Poupança Pessoal): ((Receitas - Despesas) / Receitas) × 100
      Mede quanto % da renda foi efetivamente poupado após pagar todas as despesas.
      
    - ILI (Índice de Liquidez Imediata): Reservas Líquidas / Média Despesas Essenciais (3 meses)
      Mede quantos meses a reserva de emergência consegue cobrir despesas essenciais.
      Recomendado: ≥6 meses.
    
    Args:
        user: Usuário para cálculo dos indicadores
        
    Returns:
        Dicionário com indicadores e totais financeiros
    """
    # Verificar cache
    profile, _ = UserProfile.objects.get_or_create(user=user)
    if not profile.should_recalculate_indicators():
        # Usar valores em cache
        return {
            "tps": profile.cached_tps or Decimal("0.00"),
            "rdr": profile.cached_rdr or Decimal("0.00"),
            "ili": profile.cached_ili or Decimal("0.00"),
            "total_income": profile.cached_total_income or Decimal("0.00"),
            "total_expense": profile.cached_total_expense or Decimal("0.00"),
        }
    
    # ============================================================================
    # CÁLCULO: Queries otimizadas
    # ============================================================================
    
    # Query 1: Buscar total de income
    total_income = _decimal(
        Transaction.objects.filter(
            user=user,
            type=Transaction.TransactionType.INCOME
        ).aggregate(total=Coalesce(Sum('amount'), Decimal("0")))['total']
    )
    
    # Query 2: Buscar total de expense
    total_expense = _decimal(
        Transaction.objects.filter(
            user=user,
            type=Transaction.TransactionType.EXPENSE
        ).aggregate(total=Coalesce(Sum('amount'), Decimal("0")))['total']
    )
    
    # Query 3: Calcular despesas médias mensais para RDR
    # IMPORTANTE: RDR deve considerar TODAS as despesas do mês (fixas + variáveis)
    # para mostrar o comprometimento REAL da renda
    today = timezone.now().date()
    current_month_start = today.replace(day=1)
    three_months_ago = current_month_start - relativedelta(months=3)
    
    # Buscar despesas dos últimos 3 meses completos + mês atual parcial
    monthly_expenses = Transaction.objects.filter(
        user=user,
        type=Transaction.TransactionType.EXPENSE,
        date__gte=three_months_ago,
        date__lte=today
    ).annotate(
        month=TruncMonth('date')
    ).values('month').annotate(
        total=Sum('amount')
    ).values('month', 'total')
    
    # Calcular média mensal de despesas
    if monthly_expenses.exists():
        total_expenses_period = sum(Decimal(str(m['total'])) for m in monthly_expenses)
        months_count = monthly_expenses.count()
        recurring_expenses = total_expenses_period / Decimal(str(months_count)) if months_count > 0 else Decimal("0")
    else:
        recurring_expenses = Decimal("0")

    # Calcular reserva de emergência usando o grupo SAVINGS
    # - INCOME em categoria SAVINGS = aporte na reserva (dinheiro guardado)
    # - EXPENSE em categoria SAVINGS = resgate da reserva (dinheiro retirado)
    # Saldo da reserva = Total de aportes (INCOME) - Total de resgates (EXPENSE)
    reserve_transactions = Transaction.objects.filter(
        user=user, 
        category__group=Category.CategoryGroup.SAVINGS
    ).values("type").annotate(total=Sum("amount"))
    
    reserve_deposits = Decimal("0")  # Aportes (INCOME)
    reserve_withdrawals = Decimal("0")  # Resgates (EXPENSE)
    
    for item in reserve_transactions:
        tx_type = item["type"]
        total = _decimal(item["total"])
        if tx_type == Transaction.TransactionType.INCOME:
            reserve_deposits += total
        elif tx_type == Transaction.TransactionType.EXPENSE:
            reserve_withdrawals += total

    # Calcular média de despesas essenciais dos últimos 3 meses para ILI mais estável
    # Reutilizar a variável today e three_months_ago já definidas acima
    essential_expense_total = _decimal(
        Transaction.objects.filter(
            user=user,
            category__group=Category.CategoryGroup.ESSENTIAL_EXPENSE,
            type=Transaction.TransactionType.EXPENSE,
            date__gte=three_months_ago,
            date__lte=today,
        ).aggregate(total=Sum("amount"))["total"]
    )
    # Média mensal de despesas essenciais
    essential_expense = essential_expense_total / Decimal("3") if essential_expense_total > 0 else Decimal("0")

    # ============================================================================
    # CÁLCULO DOS INDICADORES
    # ============================================================================
    
    tps = Decimal("0")
    rdr = Decimal("0")
    ili = Decimal("0")
    
    if total_income > 0:
        # TPS (Taxa de Poupança Pessoal)
        # Fórmula: ((Receitas - Despesas) / Receitas) × 100
        # 
        # Exemplo: Ganhou R$ 5.000, gastou R$ 2.000
        # TPS = (5.000 - 2.000) / 5.000 × 100 = 60%
        savings = total_income - total_expense
        tps = (savings / total_income) * Decimal("100")
        
        # RDR (Razão Despesas/Renda) - RENOMEADO de "Despesas Recorrentes"
        # Fórmula: (Média Mensal de TODAS as Despesas / Receitas) × 100
        # Mede quanto % da renda está comprometido com gastos mensais (fixos + variáveis)
        # 
        # IMPORTANTE: Considera TODAS as despesas do período (últimos 3 meses),
        # não apenas as marcadas como recorrentes. Isso dá uma visão realista
        # do comprometimento mensal da renda.
        # 
        # Exemplo: Ganhou R$ 5.000, média mensal de gastos é R$ 1.500
        # RDR = 1.500 / 5.000 × 100 = 30%
        # 
        # Referências:
        # - ≤35%: Saudável (sobra boa margem)
        # - 36-50%: Atenção (pouca flexibilidade)
        # - ≥51%: Crítico (muito comprometido)
        rdr = (recurring_expenses / total_income) * Decimal("100")
    
    # ILI (Índice de Liquidez Imediata)
    # Fórmula: Reserva de Emergência / Despesas Essenciais Mensais
    # Representa quantos meses a reserva consegue cobrir despesas essenciais
    # 
    # Exemplo: Tem R$ 12.000 de reserva, gasta R$ 2.000/mês em essenciais
    # ILI = 12.000 / 2.000 = 6 meses
    # 
    # Recomendação padrão: 3-6 meses (mínimo), idealmente 6-12 meses
    reserve_balance = reserve_deposits - reserve_withdrawals
    if essential_expense > 0:
        ili = reserve_balance / essential_expense

    # Atualizar cache
    profile.cached_tps = tps.quantize(Decimal("0.01")) if total_income > 0 else Decimal("0.00")
    profile.cached_rdr = rdr.quantize(Decimal("0.01")) if total_income > 0 else Decimal("0.00")
    profile.cached_ili = ili.quantize(Decimal("0.01")) if essential_expense > 0 else Decimal("0.00")
    profile.cached_total_income = total_income.quantize(Decimal("0.01"))
    profile.cached_total_expense = total_expense.quantize(Decimal("0.01"))
    profile.indicators_updated_at = timezone.now()
    profile.save(update_fields=[
        'cached_tps',
        'cached_rdr', 
        'cached_ili', 
        'cached_total_income',
        'cached_total_expense',
        'indicators_updated_at'
    ])

    return {
        "tps": profile.cached_tps,
        "rdr": profile.cached_rdr,
        "ili": profile.cached_ili,
        "total_income": profile.cached_total_income,
        "total_expense": profile.cached_total_expense,
    }


def invalidate_indicators_cache(user) -> None:
    """
    Invalida o cache de indicadores, forçando recálculo na próxima consulta.
    Deve ser chamado após criar/editar/deletar transações e transaction links.
    
    Args:
        user: Usuário cujo cache deve ser invalidado
    """
    try:
        profile = UserProfile.objects.get(user=user)
        profile.indicators_updated_at = None
        profile.save(update_fields=['indicators_updated_at'])
    except UserProfile.DoesNotExist:
        pass


def auto_link_recurring_transactions(user) -> int:
    """
    Vincula automaticamente transações recorrentes baseado em configuração.
    
    Lógica:
    1. Buscar todos os TransactionLinks com is_recurring=True do usuário
    2. Para cada link recorrente:
       - Verificar se existem novas instâncias das transações recorrentes
       - Criar links automáticos entre as novas instâncias
    
    Args:
        user: Usuário para processar vinculações automáticas
    
    Returns:
        Número de links criados automaticamente
    """
    from .models import Transaction, TransactionLink
    
    links_created = 0
    
    # Buscar links recorrentes ativos
    recurring_links = TransactionLink.objects.filter(
        user=user,
        is_recurring=True
    ).select_related('source_transaction', 'target_transaction')
    
    for link in recurring_links:
        source = link.source_transaction
        target = link.target_transaction
        
        # Verificar se ambas são recorrentes
        if not (source.is_recurring and target.is_recurring):
            continue
        
        # Calcular delta de tempo baseado na recorrência
        if source.recurrence_unit == Transaction.RecurrenceUnit.DAYS:
            delta_days = source.recurrence_value
        elif source.recurrence_unit == Transaction.RecurrenceUnit.WEEKS:
            delta_days = source.recurrence_value * 7
        elif source.recurrence_unit == Transaction.RecurrenceUnit.MONTHS:
            delta_days = source.recurrence_value * 30  # Aproximado
        else:
            continue
        
        # Buscar transações similares criadas após a original
        # (mesma categoria, descrição, valor, tipo, recorrentes)
        next_sources = Transaction.objects.filter(
            user=user,
            type=source.type,
            category=source.category,
            description=source.description,
            amount=source.amount,
            date__gt=source.date,
            is_recurring=True,
        ).exclude(
            # Excluir transações já vinculadas como source
            id__in=TransactionLink.objects.filter(
                user=user,
                link_type=link.link_type
            ).values_list('source_transaction_id', flat=True)
        )
        
        next_targets = Transaction.objects.filter(
            user=user,
            category=target.category,
            description=target.description,
            amount=target.amount,
            date__gt=target.date,
            is_recurring=True,
        ).exclude(
            # Excluir transações já vinculadas como target
            id__in=TransactionLink.objects.filter(
                user=user,
                link_type=link.link_type
            ).values_list('target_transaction_id', flat=True)
        )
        
        # Criar links entre pares correspondentes (uma de cada vez para segurança)
        for next_source in next_sources[:1]:
            for next_target in next_targets[:1]:
                # Verificar se há saldo disponível
                if next_source.available_amount >= link.linked_amount:
                    if next_target.available_amount >= link.linked_amount:
                        try:
                            # Criar link automático
                            TransactionLink.objects.create(
                                user=user,
                                source_transaction=next_source,
                                target_transaction=next_target,
                                linked_amount=link.linked_amount,
                                link_type=link.link_type,
                                description=f"Auto: {link.description}" if link.description else "Vinculação automática recorrente",
                                is_recurring=True
                            )
                            links_created += 1
                        except Exception as e:
                            # Log erro mas continua processando outros links
                            print(f"Erro ao criar link automático: {e}")
                            continue
    
    # Invalidar cache se criou links
    if links_created > 0:
        invalidate_indicators_cache(user)
    
    return links_created


def category_breakdown(user) -> Dict[str, List[Dict[str, str]]]:
    """
    Quebra transações por categoria, agrupando por tipo.
    
    Returns:
        Dicionário com listas de categorias por tipo (INCOME, EXPENSE)
    """
    buckets: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    queryset = (
        Transaction.objects.filter(user=user, category__isnull=False)
        .values("category__name", "category__type", "category__group")
        .annotate(total=Coalesce(Sum("amount"), Decimal("0")))
        .order_by("category__name")
    )

    for item in queryset:
        total_value = _decimal(item["total"])
        buckets[item["category__type"]].append(
            {
                "name": item["category__name"],
                "group": item.get("category__group") or Category.CategoryGroup.OTHER,
                "total": total_value.quantize(Decimal("0.01")),
            }
        )
    return buckets


def cashflow_series(user, months: int = 6) -> List[Dict[str, str]]:
    """
    Gera série temporal de fluxo de caixa e indicadores mensais.
    Inclui dados históricos e projeções baseadas em transações recorrentes.
    
    Args:
        user: Usuário para análise
        months: Número de meses retroativos a incluir (padrão: 6)
        
    Returns:
        Lista de dicionários com dados mensais (income, expense, debt, tps, rdr, is_projection)
        Filtra meses sem nenhuma transação ou projeção.
    """
    now = timezone.now().date()
    current_month = now.replace(day=1)
    first_day = (now.replace(day=1) - timedelta(days=months * 31)).replace(day=1)
    
    # Buscar transações históricas
    data = (
        Transaction.objects.filter(user=user, date__gte=first_day)
        .annotate(month=TruncMonth("date"))
        .values("month", "type")
        .annotate(total=Sum("amount"))
    )

    buckets: Dict[date, Dict[str, Decimal]] = defaultdict(lambda: defaultdict(Decimal))
    for item in data:
        month_value = item["month"]
        if isinstance(month_value, datetime):
            month = month_value.date()
        else:
            month = month_value
        buckets[month][item["type"]] += _decimal(item["total"])

    # Calcular projeções de recorrências para os próximos 3 meses
    recurrence_projections: Dict[date, Dict[str, Decimal]] = defaultdict(lambda: defaultdict(Decimal))
    
    # Buscar todas as transações recorrentes ativas (que não tem data final ou data final está no futuro)
    active_recurrences = Transaction.objects.filter(
        user=user,
        is_recurring=True,
    ).filter(
        Q(recurrence_end_date__isnull=True) | Q(recurrence_end_date__gte=now)
    )
    
    for transaction in active_recurrences:
        # Projetar para os próximos 3 meses
        projection_month = current_month
        for _ in range(3):
            projection_month = projection_month + timedelta(days=32)
            projection_month = projection_month.replace(day=1)
            
            # Verificar se deve gerar para este mês
            if transaction.recurrence_unit == Transaction.RecurrenceUnit.MONTHS:
                # Mensal - adiciona o valor completo
                recurrence_projections[projection_month][transaction.type] += transaction.amount
            elif transaction.recurrence_unit == Transaction.RecurrenceUnit.WEEKS:
                # Semanal - estimar ~4 ocorrências por mês
                recurrence_projections[projection_month][transaction.type] += transaction.amount * 4
            elif transaction.recurrence_unit == Transaction.RecurrenceUnit.DAYS:
                # Diário - estimar ~30 ocorrências por mês (ou usar recurrence_value)
                if transaction.recurrence_value:
                    occurrences_per_month = 30 // transaction.recurrence_value
                    recurrence_projections[projection_month][transaction.type] += transaction.amount * occurrences_per_month
                else:
                    recurrence_projections[projection_month][transaction.type] += transaction.amount * 30

    series: List[Dict[str, str]] = []
    current = first_day
    
    # Gerar série incluindo meses passados e futuros
    end_month = current_month + timedelta(days=100)  # ~3 meses no futuro
    while current <= end_month:
        is_future = current > current_month
        
        if is_future:
            # Usar projeções para meses futuros
            income = recurrence_projections[current].get(Transaction.TransactionType.INCOME, Decimal("0"))
            expense = recurrence_projections[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
        else:
            # Usar dados reais para meses passados
            income = buckets[current].get(Transaction.TransactionType.INCOME, Decimal("0"))
            expense = buckets[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
        
        # Calcular TPS inline
        tps = Decimal("0")
        if income > 0:
            savings = income - expense
            tps = (savings / income) * Decimal("100")
        
        # Calcular RDR (despesas recorrentes / renda)
        rdr = Decimal("0")
        if income > 0:
            # Para meses futuros, usar as projeções de recorrências
            # Para meses passados, calcular despesas recorrentes reais
            if is_future:
                recurring_expenses = recurrence_projections[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
            else:
                # Buscar despesas recorrentes do mês
                recurring_expenses = Transaction.objects.filter(
                    user=user,
                    type=Transaction.TransactionType.EXPENSE,
                    is_recurring=True,
                    date__year=current.year,
                    date__month=current.month
                ).aggregate(total=Sum('amount'))['total'] or Decimal("0")
            
            rdr = (recurring_expenses / income) * Decimal("100")
        
        # Filtrar meses sem dados
        if income > 0 or expense > 0:
            series.append(
                {
                    "month": current.strftime("%Y-%m"),
                    "income": income.quantize(Decimal("0.01")),
                    "expense": expense.quantize(Decimal("0.01")),
                    "tps": tps.quantize(Decimal("0.01")),
                    "rdr": rdr.quantize(Decimal("0.01")),
                    "is_projection": is_future,
                }
            )
        
        # Avançar para o próximo mês
        if current.month == 12:
            current = current.replace(year=current.year + 1, month=1)
        else:
            current = current.replace(month=current.month + 1)
    
    return series


def _xp_threshold(level: int) -> int:
    return 150 + (level - 1) * 50


def apply_mission_reward(progress: MissionProgress) -> None:
    """
    Aplica recompensa de XP ao completar uma missão.
    Usa transaction.atomic e select_for_update para evitar race conditions.
    Cria registro de auditoria para rastreamento.
    
    Args:
        progress: MissionProgress que foi completada
    """
    from django.db import transaction
    from .models import XPTransaction
    
    with transaction.atomic():
        # Lock no perfil para evitar condições de corrida
        profile = UserProfile.objects.select_for_update().get(user=progress.user)
        
        # Salvar estado anterior para auditoria
        level_before = profile.level
        xp_before = profile.experience_points
        
        # Adicionar XP da recompensa
        profile.experience_points += progress.mission.reward_points

        # Processar level ups
        while profile.experience_points >= _xp_threshold(profile.level):
            profile.experience_points -= _xp_threshold(profile.level)
            profile.level += 1
        
        profile.save(update_fields=["experience_points", "level"])
        
        # Criar registro de auditoria
        XPTransaction.objects.create(
            user=progress.user,
            mission_progress=progress,
            points_awarded=progress.mission.reward_points,
            level_before=level_before,
            level_after=profile.level,
            xp_before=xp_before,
            xp_after=profile.experience_points,
        )


def profile_snapshot(user) -> Dict[str, int]:
    profile, _ = UserProfile.objects.get_or_create(user=user)
    return {
        "level": profile.level,
        "experience_points": profile.experience_points,
        "next_level_threshold": profile.next_level_threshold,
        "target_tps": profile.target_tps,
        "target_rdr": profile.target_rdr,
        "target_ili": profile.target_ili,
        "is_first_access": profile.is_first_access,  # Incluído para onboarding
    }


def indicator_insights(summary: Dict[str, Decimal], profile: UserProfile) -> Dict[str, Dict[str, str]]:
    """Gera dicas alinhadas às faixas descritas no texto."""

    def _quantize(value: Decimal) -> Decimal:
        return value.quantize(Decimal("0.01"))

    def _tps_status(value: Decimal) -> Dict[str, str]:
        numero = float(value)
        if numero >= profile.target_tps:
            return {
                "severity": "good",
                "title": "Boa disciplina",
                "message": "A poupança tá batendo a meta, segue no ritmo.",
            }
        if numero >= 10:
            return {
                "severity": "attention",
                "title": "Quase lá",
                "message": f"Dá pra cortar uns gastos pra chegar nos {profile.target_tps}% esperados.",
            }
        return {
            "severity": "critical",
            "title": "Reserva apertada",
            "message": "Organiza prioridades e tenta separar algo todo mês pra não ficar no sufoco.",
        }

    def _rdr_status(value: Decimal) -> Dict[str, str]:
        numero = float(value)
        if numero <= profile.target_rdr:
            return {
                "severity": "good",
                "title": "Dívidas controladas",
                "message": "Comprometimento da renda tá saudável, mantém as parcelas em dia.",
            }
        if numero <= 42:
            return {
                "severity": "attention",
                "title": "Fica de olho",
                "message": f"Avalia renegociação ou amortização leve pra ficar abaixo dos {profile.target_rdr}%.",
            }
        if numero <= 49:
            return {
                "severity": "warning",
                "title": "Alerta ligado",
                "message": "Boa rever prioridades e conter novos créditos enquanto ajusta as dívidas.",
            }
        return {
            "severity": "critical",
            "title": "Risco alto",
            "message": "Busca renegociar e cortar gastos urgentes pra escapar de inadimplência.",
        }

    def _ili_status(value: Decimal) -> Dict[str, str]:
        numero = float(value)
        alvo = float(profile.target_ili)
        if numero >= alvo:
            return {
                "severity": "good",
                "title": "Reserva sólida",
                "message": "Liquidez cobre vários meses, dá pra pensar em diversificar investimentos.",
            }
        if numero >= 3:
            return {
                "severity": "attention",
                "title": "Cofre em construção",
                "message": "Reserva segura por poucos meses, planeja aportes automáticos pra chegar na meta.",
            }
        return {
            "severity": "critical",
            "title": "Almofada curta",
            "message": "Prioriza formar reserva de emergência pra aguentar imprevistos sem recorrer a crédito.",
        }

    tps_value = summary.get("tps", Decimal("0"))
    rdr_value = summary.get("rdr", Decimal("0"))
    ili_value = summary.get("ili", Decimal("0"))

    tps_info = _tps_status(tps_value)
    rdr_info = _rdr_status(rdr_value)
    ili_info = _ili_status(ili_value)

    return {
        "tps": {
            "value": _quantize(tps_value),
            "target": profile.target_tps,
            **tps_info,
        },
        "rdr": {
            "value": _quantize(rdr_value),
            "target": profile.target_rdr,
            **rdr_info,
        },
        "ili": {
            "value": _quantize(ili_value),
            "target": profile.target_ili.quantize(Decimal("0.01")),
            **ili_info,
        },
    }


def recommend_missions(user, summary: Dict[str, Decimal]) -> Iterable[Mission]:
    """
    DEPRECATED: Mantido apenas para compatibilidade.
    Use assign_missions_automatically() para atribuição automática.
    """
    user_tps = summary.get("tps", Decimal("0"))
    user_rdr = summary.get("rdr", Decimal("0"))
    user_ili = summary.get("ili", Decimal("0"))

    already_linked = set(
        MissionProgress.objects.filter(user=user).values_list("mission_id", flat=True)
    )

    base_queryset = Mission.objects.filter(is_active=True).exclude(id__in=already_linked)

    selected: List[Mission] = []
    for mission in base_queryset:
        match_tps = mission.target_tps is None or user_tps < Decimal(mission.target_tps)
        match_rdr = mission.target_rdr is None or user_rdr > Decimal(mission.target_rdr)
        match_ili = True
        if mission.min_ili is not None and user_ili < mission.min_ili:
            match_ili = False
        if mission.max_ili is not None and user_ili > mission.max_ili:
            match_ili = False
        if match_tps and match_rdr and match_ili:
            selected.append(mission)

    if not selected:
        selected = list(base_queryset[:3])

    return selected[:3]


def assign_missions_automatically(user) -> List[MissionProgress]:
    """
    Atribui missões automaticamente baseado nos índices do usuário.
    
    Lógica de atribuição:
    1. Usuários novos (< 5 transações): missões ONBOARDING
    2. ILI <= 3: prioriza ILI_BUILDING
    3. RDR >= 50: prioriza RDR_REDUCTION
    4. TPS < 10: prioriza TPS_IMPROVEMENT
    5. ILI entre 3-6: missões de controle
    6. ILI >= 6: missões ADVANCED
    
    Retorna lista de MissionProgress criadas ou atualizadas.
    """
    from django.utils import timezone
    
    summary = calculate_summary(user)
    tps = float(summary.get("tps", Decimal("0")))
    rdr = float(summary.get("rdr", Decimal("0")))
    ili = float(summary.get("ili", Decimal("0")))
    
    transaction_count = Transaction.objects.filter(user=user).count()
    
    # Buscar missões já atribuídas (incluindo completadas para não repetir)
    existing_progress = MissionProgress.objects.filter(user=user)
    active_count = existing_progress.filter(
        status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
    ).count()
    
    # Se já tem 3 ou mais missões ativas, não atribui novas
    if active_count >= 3:
        return list(existing_progress.filter(
            status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
        ))
    
    # Determinar tipo de missão prioritária
    priority_types = []
    
    if transaction_count < 5:
        priority_types = ['ONBOARDING_TRANSACTIONS']
    elif ili <= 3:
        priority_types = ['ILI_BUILDING', 'TPS_IMPROVEMENT']
    elif rdr >= 50:
        priority_types = ['RDR_REDUCTION']
    elif tps < 10:
        priority_types = ['TPS_IMPROVEMENT', 'ILI_BUILDING']
    elif 3 < ili < 6:
        priority_types = ['TPS_IMPROVEMENT', 'ILI_BUILDING']
    elif ili >= 6:
        priority_types = ['FINANCIAL_HEALTH']
    else:
        priority_types = ['TPS_IMPROVEMENT']
    
    # Buscar missões já linkadas ao usuário (incluindo completadas para não repetir)
    already_linked = set(
        existing_progress.values_list("mission_id", flat=True)
    )
    
    # Buscar missões disponíveis
    available_missions = Mission.objects.filter(
        is_active=True,
        mission_type__in=priority_types,
    ).exclude(id__in=already_linked).order_by('priority')
    
    # Filtrar por critérios de índices - apenas missões que fazem sentido
    suitable_missions = []
    for mission in available_missions:
        # Verificar número mínimo de transações
        if mission.min_transactions and transaction_count < mission.min_transactions:
            continue
        
        # Verificar TPS - só atribui se usuário está ABAIXO do target (precisa melhorar)
        if mission.target_tps is not None:
            if tps >= mission.target_tps:
                # Usuário já está acima do target, missão não faz sentido
                continue
        
        # Verificar RDR - só atribui se usuário está ACIMA do target (precisa reduzir)
        if mission.target_rdr is not None:
            if rdr <= mission.target_rdr:
                # Usuário já está abaixo do target, missão não faz sentido
                continue
        
        # Verificar ILI - só atribui se está na faixa adequada
        if mission.min_ili is not None:
            if ili >= float(mission.min_ili):
                # Usuário já atingiu o mínimo, missão não faz sentido
                continue
        
        if mission.max_ili is not None:
            if ili > float(mission.max_ili):
                # Usuário está acima do máximo, missão não faz sentido
                continue
        
        # Validação adicional: não atribuir missão que seria completada instantaneamente
        # Apenas para missões que não são de ONBOARDING
        if mission.mission_type not in ['ONBOARDING_TRANSACTIONS', 'ONBOARDING_CATEGORIES', 'ONBOARDING_GOALS']:
            would_complete_instantly = False
            
            # Verificar se TPS já atende o target
            if mission.target_tps is not None and tps >= mission.target_tps * 0.95:
                would_complete_instantly = True
            
            # Verificar se RDR já atende o target
            if mission.target_rdr is not None and rdr <= mission.target_rdr * 1.05:
                would_complete_instantly = True
            
            # Verificar se ILI já atende o target
            if mission.min_ili is not None and ili >= float(mission.min_ili) * 0.95:
                would_complete_instantly = True
            
            if would_complete_instantly:
                # Missão seria completada muito rapidamente, buscar outra
                continue
        
        suitable_missions.append(mission)
        
        # Limitar para preencher até 3 missões ativas
        if len(suitable_missions) >= (3 - active_count):
            break
    
    # Se não encontrou missões adequadas com filtros rigorosos, relaxa um pouco
    if not suitable_missions and active_count == 0:
        # Pega qualquer missão do tipo prioritário que o usuário não tenha
        suitable_missions = list(available_missions[:3])
    
    # Se ainda não tem e usuário tem 0 missões, pega qualquer missão ativa
    if not suitable_missions and active_count == 0:
        suitable_missions = list(
            Mission.objects.filter(is_active=True)
            .exclude(id__in=already_linked)
            .order_by('priority')[:3]
        )
    
    # Criar MissionProgress para as missões selecionadas
    created_progress = []
    for mission in suitable_missions:
        progress, created = MissionProgress.objects.get_or_create(
            user=user,
            mission=mission,
            defaults={
                'status': MissionProgress.Status.PENDING,
                'progress': Decimal("0.00"),
                'initial_tps': Decimal(str(tps)),
                'initial_rdr': Decimal(str(rdr)),
                'initial_ili': Decimal(str(ili)),
                'initial_transaction_count': transaction_count,
            }
        )
        if created:
            # Inicializar baselines e configurações para missões com validation_type especial
            initialize_mission_progress(progress)
            created_progress.append(progress)
    
    return created_progress


def update_mission_progress(user) -> List[MissionProgress]:
    """
    Atualiza o progresso das missões ativas do usuário baseado em seus dados atuais.
    
    ATUALIZADO: Usa validadores especializados por tipo de missão (mission_types.py).
    
    Fluxo:
    1. Busca missões ativas com lock (evita race conditions)
    2. Para cada missão, usa validator específico do tipo
    3. Atualiza progresso e verifica conclusão
    4. Aplica recompensas se completou
    
    Returns:
        Lista de missões que tiveram progresso atualizado.
    """
    from django.db import transaction
    from django.utils import timezone
    from .mission_types import MissionValidatorFactory
    
    # Usar select_for_update para evitar condições de corrida
    with transaction.atomic():
        active_missions = MissionProgress.objects.select_for_update().filter(
            user=user,
            status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
        )
        
        if not active_missions:
            return []
        
        # Converter para lista para trabalhar fora do lock
        missions_to_update = list(active_missions)
    
    updated = []
    
    for progress in missions_to_update:
        try:
            # Usar validator especializado
            validator = MissionValidatorFactory.create_validator(
                progress.mission,
                user,
                progress
            )
            
            # Calcular progresso usando o validator
            result = validator.calculate_progress()
            
            old_progress = float(progress.progress)
            new_progress = result['progress_percentage']
            
            # Atualizar progresso
            progress.progress = Decimal(str(new_progress))
            
            # Verificar se completou
            if result['is_completed'] and not progress.completed_at:
                is_valid, message = validator.validate_completion()
                
                if is_valid:
                    progress.completed_at = timezone.now()
                    progress.is_completed = True
                    progress.status = MissionProgress.Status.COMPLETED
                    progress.save()
                    
                    # Aplicar recompensa
                    apply_mission_reward(progress)
                    
                    logger.info(f"Missão completada: {progress.mission.title} - {message}")
                else:
                    progress.save()
            else:
                progress.save()
            
            # Registrar mudança significativa
            if abs(new_progress - old_progress) > 0.1:
                updated.append(progress)
                logger.debug(f"Progresso atualizado para {progress.mission.title}: {old_progress:.1f}% → {new_progress:.1f}%")
                
        except Exception as e:
            logger.error(f"Erro ao atualizar progresso da missão {progress.mission.title}: {e}")
            continue
    
    return updated


def _legacy_update_mission_progress(user, progress) -> float:
    """
    DEPRECATED: Lógica antiga de cálculo de progresso.
    Mantido apenas para compatibilidade com missões antigas sem validator.
    
    Use update_mission_progress() com validators especializados.
    """
    summary = calculate_summary(user)
    current_tps = float(summary.get("tps", Decimal("0")))
    current_rdr = float(summary.get("rdr", Decimal("0")))
    current_ili = float(summary.get("ili", Decimal("0")))
    current_transaction_count = Transaction.objects.filter(user=user).count()
    
    mission = progress.mission
    new_progress = 0.0
    
    # Inicializar valores iniciais se None (para missões antigas)
    if progress.initial_tps is None:
        progress.initial_tps = Decimal(str(current_tps))
    if progress.initial_rdr is None:
        progress.initial_rdr = Decimal(str(current_rdr))
    if progress.initial_ili is None:
        progress.initial_ili = Decimal(str(current_ili))
    if progress.initial_transaction_count == 0:
        progress.initial_transaction_count = max(1, current_transaction_count)
    
    # Garantir que valores não sejam None antes de calcular
    initial_tps = float(progress.initial_tps) if progress.initial_tps is not None else 0.0
    initial_rdr = float(progress.initial_rdr) if progress.initial_rdr is not None else 0.0
    initial_ili = float(progress.initial_ili) if progress.initial_ili is not None else 0.0
    
    # Calcular progresso baseado no tipo de missão
    if mission.mission_type in ['ONBOARDING_TRANSACTIONS', 'ONBOARDING_CATEGORIES', 'ONBOARDING_GOALS']:
        # Para onboarding, progresso é baseado em número de transações
        if mission.min_transactions:
            new_progress = min(100.0, (current_transaction_count / mission.min_transactions) * 100)
        else:
            # Se não especificou mínimo, considera 10 transações como meta
            new_progress = min(100.0, (current_transaction_count / 10) * 100)
    
    elif mission.mission_type == 'TPS_IMPROVEMENT':
        # Progresso baseado em melhoria do TPS
        if mission.target_tps is not None:
            initial = float(progress.initial_tps) if progress.initial_tps else 0.0
            target = float(mission.target_tps)
            
            if current_tps >= target:
                # Atingiu ou superou a meta
                new_progress = 100.0
            elif target > initial and (target - initial) > 0:
                # Precisa melhorar
                improvement = current_tps - initial
                needed = target - initial
                new_progress = min(100.0, max(0.0, (improvement / needed) * 100))
            elif initial >= target:
                # Já estava acima da meta no início
                new_progress = 100.0
            else:
                new_progress = 100.0 if current_tps >= target else 0.0
    
    elif mission.mission_type == 'RDR_REDUCTION':
        # Progresso baseado em redução do RDR
        if mission.target_rdr is not None:
            initial = float(progress.initial_rdr) if progress.initial_rdr else 0.0
            target = float(mission.target_rdr)
            
            if current_rdr <= target:
                new_progress = 100.0
            elif initial > target and (initial - target) > 0:
                reduction = initial - current_rdr
                needed = initial - target
                new_progress = min(100.0, max(0.0, (reduction / needed) * 100))
            elif initial <= target:
                new_progress = 100.0
            else:
                new_progress = 100.0 if current_rdr <= target else 0.0
    
    elif mission.mission_type == 'ILI_BUILDING':
        # Progresso baseado em construção do ILI
        if mission.min_ili is not None:
            initial = float(progress.initial_ili) if progress.initial_ili else 0.0
            target = float(mission.min_ili)
            
            if current_ili >= target:
                new_progress = 100.0
            elif target > initial and (target - initial) > 0:
                improvement = current_ili - initial
                needed = target - initial
                new_progress = min(100.0, max(0.0, (improvement / needed) * 100))
            elif initial >= target:
                new_progress = 100.0
            else:
                new_progress = 100.0 if current_ili >= target else 0.0
    
    elif mission.mission_type == 'FINANCIAL_HEALTH':
        # Missões avançadas com múltiplos critérios
        progress_components = []
        
        if mission.target_tps is not None and progress.initial_tps is not None:
            initial = float(progress.initial_tps)
            target = float(mission.target_tps)
            if current_tps >= target:
                progress_components.append(100.0)
            elif target > initial and (target - initial) > 0:
                progress_components.append(min(100.0, max(0.0, ((current_tps - initial) / (target - initial)) * 100)))
            else:
                progress_components.append(100.0 if current_tps >= target else 0.0)
        
        if mission.target_rdr is not None and progress.initial_rdr is not None:
            initial = float(progress.initial_rdr)
            target = float(mission.target_rdr)
            if current_rdr <= target:
                progress_components.append(100.0)
            elif initial > target and (initial - target) > 0:
                progress_components.append(min(100.0, max(0.0, ((initial - current_rdr) / (initial - target)) * 100)))
            else:
                progress_components.append(100.0 if current_rdr <= target else 0.0)
        
        if mission.min_ili is not None and progress.initial_ili is not None:
            initial = float(progress.initial_ili)
            target = float(mission.min_ili)
            if current_ili >= target:
                progress_components.append(100.0)
            elif target > initial and (target - initial) > 0:
                progress_components.append(min(100.0, max(0.0, ((current_ili - initial) / (target - initial)) * 100)))
            else:
                progress_components.append(100.0 if current_ili >= target else 0.0)
        
        if progress_components:
            new_progress = sum(progress_components) / len(progress_components)
        else:
            new_progress = 0.0
    
    return new_progress


# ======= Funções de Metas =======

def update_goal_progress(goal) -> None:
    """
    Atualiza o progresso de uma meta baseado nas transações relacionadas.
    
    Args:
        goal: Instância do modelo Goal
    
    Chamado automaticamente após criar/atualizar/deletar transação
    quando goal.auto_update=True.
    """
    from .models import Goal
    
    # Só atualiza se auto_update estiver ativado
    if not goal.auto_update:
        return
    
    # Obter transações relacionadas
    transactions = goal.get_related_transactions()
    
    # Calcular total
    total = _decimal(
        transactions.aggregate(total=Coalesce(Sum('amount'), Decimal('0')))['total']
    )
    
    # Adicionar o valor inicial (se houver)
    total_with_initial = total + goal.initial_amount
    
    # Para metas de redução, calcular quanto foi reduzido
    # (quanto deixou de gastar em relação ao alvo)
    if goal.is_reduction_goal:
        # Se o alvo é gastar no máximo R$ 500
        # E gastou R$ 300, progresso = R$ 200 economizados
        if total < goal.target_amount:
            goal.current_amount = goal.target_amount - total
        else:
            goal.current_amount = Decimal('0.00')
    else:
        # Para metas normais (juntar dinheiro, pagar dívidas, etc)
        goal.current_amount = total_with_initial
    
    goal.save(update_fields=['current_amount', 'updated_at'])


def update_all_active_goals(user) -> None:
    """
    Atualiza todas as metas ativas do usuário que têm auto_update=True.
    
    Args:
        user: Usuário cujas metas devem ser atualizadas
    
    Chamado após criar/atualizar/deletar qualquer transação.
    """
    from .models import Goal
    
    goals = Goal.objects.filter(user=user, auto_update=True)
    for goal in goals:
        update_goal_progress(goal)


def get_goal_insights(goal) -> Dict[str, str]:
    """
    Gera insights e sugestões para uma meta específica.
    
    Args:
        goal: Instância do modelo Goal
    
    Returns:
        Dict com insights sobre o progresso da meta
    """
    from .models import Goal
    
    insights = {
        'status': '',
        'message': '',
        'suggestion': ''
    }
    
    progress = goal.progress_percentage
    
    # Insights baseados no progresso
    if progress >= 100:
        insights['status'] = 'completed'
        insights['message'] = '🎉 Parabéns! Você atingiu sua meta!'
        insights['suggestion'] = 'Considere criar uma nova meta para continuar evoluindo.'
    elif progress >= 75:
        insights['status'] = 'almost_there'
        insights['message'] = '💪 Falta pouco! Você está quase lá!'
        remaining = goal.target_amount - goal.current_amount
        insights['suggestion'] = f'Faltam apenas R$ {remaining:.2f} para completar.'
    elif progress >= 50:
        insights['status'] = 'on_track'
        insights['message'] = '📈 Você está no caminho certo!'
        insights['suggestion'] = 'Continue assim e você alcançará sua meta.'
    elif progress >= 25:
        insights['status'] = 'needs_attention'
        insights['message'] = '⚠️ Atenção! Progresso está lento.'
        insights['suggestion'] = 'Considere aumentar seu esforço para atingir a meta.'
    else:
        insights['status'] = 'just_started'
        insights['message'] = '🚀 Você está começando!'
        insights['suggestion'] = 'Mantenha o foco e a disciplina.'
    
    # Insights baseados no prazo
    if goal.deadline:
        today = date.today()
        days_remaining = (goal.deadline - today).days
        
        if days_remaining < 0:
            insights['message'] += f' (Prazo expirou há {abs(days_remaining)} dias)'
        elif days_remaining <= 7:
            insights['message'] += f' (Faltam {days_remaining} dias!)'
        elif days_remaining <= 30:
            insights['message'] += f' (Faltam {days_remaining} dias)'
    
    # Insights específicos por tipo de meta
    if goal.goal_type == Goal.GoalType.CATEGORY_EXPENSE and goal.is_reduction_goal:
        if progress < 50 and goal.tracking_period == Goal.TrackingPeriod.MONTHLY:
            # Se está gastando muito no mês
            insights['suggestion'] = f'Tente reduzir gastos em {goal.target_category.name}. ' + insights['suggestion']
    
    return insights


# ============================================================================
# FUNÇÕES PARA SISTEMA DE SNAPSHOTS E VALIDAÇÃO AVANÇADA
# ============================================================================

def initialize_mission_progress(progress):
    """
    Inicializa MissionProgress com todos os baselines necessários.
    
    Chamado quando missão é atribuída ao usuário pela primeira vez.
    
    Args:
        progress: Instância de MissionProgress a ser inicializada
    """
    from datetime import timedelta
    
    user = progress.user
    mission = progress.mission
    
    # Calcular summary atual
    summary = calculate_summary(user)
    
    # Valores iniciais padrão (já existentes)
    progress.initial_tps = summary.get('tps', Decimal('0'))
    progress.initial_rdr = summary.get('rdr', Decimal('0'))
    progress.initial_ili = summary.get('ili', Decimal('0'))
    progress.initial_transaction_count = Transaction.objects.filter(user=user).count()
    
    # === NOVOS BASELINES ===
    
    # Para missões de categoria
    if mission.validation_type in ['CATEGORY_REDUCTION', 'CATEGORY_LIMIT']:
        if mission.target_category:
            # Calcular baseline dos últimos 30 dias
            baseline_days = 30
            start_date = timezone.now().date() - timedelta(days=baseline_days)
            
            baseline = Transaction.objects.filter(
                user=user,
                type='EXPENSE',
                category=mission.target_category,
                date__gte=start_date
            ).aggregate(total=Sum('amount'))
            
            progress.baseline_category_spending = baseline.get('total') or Decimal('0')
            progress.baseline_period_days = baseline_days
    
    # Para missões de meta
    if mission.validation_type == 'GOAL_PROGRESS':
        if mission.target_goal:
            goal = mission.target_goal
            progress.initial_goal_progress = goal.progress
    
    # Para missões de poupança
    if mission.validation_type == 'SAVINGS_INCREASE':
        # Total atual em poupança
        savings = Transaction.objects.filter(
            user=user,
            type='INCOME',
            category__group__in=['SAVINGS', 'INVESTMENT']
        ).aggregate(total=Sum('amount'))
        
        progress.initial_savings_amount = savings.get('total') or Decimal('0')
    
    # Iniciar como PENDING
    progress.status = MissionProgress.Status.PENDING
    progress.current_streak = 0
    progress.max_streak = 0
    progress.days_met_criteria = 0
    progress.days_violated_criteria = 0
    
    progress.save()
    
    logger.info(f"Missão {mission.title} inicializada para {user.username}")


def validate_mission_progress_manual(progress):
    """
    Valida progresso de uma missão MANUALMENTE (fora do ciclo diário).
    
    Útil para:
    - Validação imediata após transação
    - Verificação on-demand pelo usuário
    - Testes
    
    Args:
        progress: Instância de MissionProgress a ser validada
    
    Returns:
        MissionProgress: Instância atualizada
    """
    from .models import UserDailySnapshot
    
    # Buscar último snapshot do usuário (ou criar temporário)
    today = timezone.now().date()
    snapshot = UserDailySnapshot.objects.filter(
        user=progress.user,
        snapshot_date=today
    ).first()
    
    if not snapshot:
        # Criar snapshot temporário (não salvo no banco)
        summary = calculate_summary(progress.user)
        
        # Importar aqui para evitar circular import
        from .tasks import (
            _calculate_category_spending,
            _calculate_goals_progress,
            _calculate_total_savings
        )
        
        month_start = today.replace(day=1)
        
        snapshot = UserDailySnapshot(
            user=progress.user,
            snapshot_date=today,
            tps=summary.get('tps', Decimal('0')),
            rdr=summary.get('rdr', Decimal('0')),
            ili=summary.get('ili', Decimal('0')),
            total_income=summary.get('total_income', Decimal('0')),
            total_expense=summary.get('total_expense', Decimal('0')),
            total_debt=summary.get('total_debt', Decimal('0')),
            available_balance=summary.get('available_balance', Decimal('0')),
            category_spending=_calculate_category_spending(progress.user, month_start, today),
            savings_total=_calculate_total_savings(progress.user),
            goals_progress=_calculate_goals_progress(progress.user),
            transactions_registered_today=Transaction.objects.filter(
                user=progress.user,
                date=today
            ).exists(),
        )
    
    # Importar funções de avaliação
    from .tasks import (
        _evaluate_mission_criteria,
        _calculate_consecutive_days,
        _calculate_mission_progress_percentage
    )
    
    # Avaliar critérios
    met_criteria, details = _evaluate_mission_criteria(progress, snapshot)
    
    # Calcular progresso
    consecutive = _calculate_consecutive_days(progress, met_criteria)
    progress_pct = _calculate_mission_progress_percentage(progress, snapshot, consecutive)
    
    # Atualizar
    progress.progress = Decimal(str(progress_pct))
    
    if progress_pct >= 100:
        progress.status = MissionProgress.Status.COMPLETED
        progress.completed_at = timezone.now()
        apply_mission_reward(progress)
    elif progress.status == MissionProgress.Status.PENDING and progress_pct > 0:
        progress.status = MissionProgress.Status.ACTIVE
        progress.started_at = timezone.now()
    
    progress.save()
    
    return progress


def analyze_user_evolution(user, days=90):
    """
    Analisa evolução do usuário nos últimos X dias.
    
    Usado pela IA para gerar missões personalizadas baseadas em histórico real.
    
    Args:
        user: Usuário a ser analisado
        days: Número de dias para análise (padrão: 90)
    
    Returns:
        dict: Análise completa de evolução do usuário
    """
    from .models import UserDailySnapshot
    from datetime import timedelta
    
    start_date = timezone.now().date() - timedelta(days=days)
    
    snapshots = UserDailySnapshot.objects.filter(
        user=user,
        snapshot_date__gte=start_date
    ).order_by('snapshot_date')
    
    if not snapshots.exists():
        return {
            'has_data': False,
            'message': 'Dados insuficientes para análise (menos de 1 dia de histórico)'
        }
    
    # Análise de TPS
    tps_data = snapshots.aggregate(
        avg=Avg('tps'),
        min=Min('tps'),
        max=Max('tps')
    )
    first_tps = float(snapshots.first().tps)
    last_tps = float(snapshots.last().tps)
    tps_trend = 'crescente' if last_tps > first_tps else 'decrescente' if last_tps < first_tps else 'estável'
    
    # Análise de RDR
    rdr_data = snapshots.aggregate(
        avg=Avg('rdr'),
        min=Min('rdr'),
        max=Max('rdr')
    )
    first_rdr = float(snapshots.first().rdr)
    last_rdr = float(snapshots.last().rdr)
    rdr_trend = 'crescente' if last_rdr > first_rdr else 'decrescente' if last_rdr < first_rdr else 'estável'
    
    # Análise de ILI
    ili_data = snapshots.aggregate(
        avg=Avg('ili'),
        min=Min('ili'),
        max=Max('ili')
    )
    first_ili = float(snapshots.first().ili)
    last_ili = float(snapshots.last().ili)
    ili_trend = 'crescente' if last_ili > first_ili else 'decrescente' if last_ili < first_ili else 'estável'
    
    # Categoria mais problemática
    all_category_spending = {}
    for snapshot in snapshots:
        for cat, data in snapshot.category_spending.items():
            if cat not in all_category_spending:
                all_category_spending[cat] = 0
            all_category_spending[cat] += data['total']
    
    problem_category = max(
        all_category_spending.items(),
        key=lambda x: x[1]
    )[0] if all_category_spending else None
    
    # Consistência de registro
    days_with_registro = snapshots.filter(
        transactions_registered_today=True
    ).count()
    consistency_rate = (days_with_registro / snapshots.count()) * 100
    
    # Identificar problemas
    problems = []
    if tps_data['avg'] < 15:
        problems.append('TPS_BAIXO')
    if rdr_data['avg'] > 40:
        problems.append('RDR_ALTO')
    if ili_data['avg'] < 3:
        problems.append('ILI_BAIXO')
    if consistency_rate < 50:
        problems.append('BAIXA_CONSISTENCIA')
    
    # Identificar pontos fortes
    strengths = []
    if tps_trend == 'crescente':
        strengths.append('TPS_MELHORANDO')
    if rdr_trend == 'decrescente':
        strengths.append('RDR_MELHORANDO')
    if ili_trend == 'crescente':
        strengths.append('ILI_MELHORANDO')
    if consistency_rate > 80:
        strengths.append('ALTA_CONSISTENCIA')
    
    return {
        'has_data': True,
        'period_days': days,
        'snapshots_count': snapshots.count(),
        'tps': {
            'average': float(tps_data['avg']),
            'min': float(tps_data['min']),
            'max': float(tps_data['max']),
            'first': first_tps,
            'last': last_tps,
            'trend': tps_trend,
        },
        'rdr': {
            'average': float(rdr_data['avg']),
            'min': float(rdr_data['min']),
            'max': float(rdr_data['max']),
            'first': first_rdr,
            'last': last_rdr,
            'trend': rdr_trend,
        },
        'ili': {
            'average': float(ili_data['avg']),
            'min': float(ili_data['min']),
            'max': float(ili_data['max']),
            'first': first_ili,
            'last': last_ili,
            'trend': ili_trend,
        },
        'categories': {
            'most_spending': problem_category,
            'all_spending': all_category_spending,
        },
        'consistency': {
            'rate': consistency_rate,
            'days_registered': days_with_registro,
            'total_days': snapshots.count(),
        },
        'problems': problems,
        'strengths': strengths,
    }


def analyze_category_patterns(user, days=90):
    """
    Analisa padrões de gastos por categoria para sugerir missões específicas.
    
    Args:
        user: Usuário a ser analisado
        days: Período de análise em dias
    
    Returns:
        dict: Análise detalhada por categoria com sugestões de missões
    """
    from .models import UserDailySnapshot
    from datetime import timedelta
    from django.core.cache import cache
    
    # Validação de entrada
    if not user or days <= 0:
        return {'has_data': False, 'error': 'Parâmetros inválidos'}
    
    # Cache de 15 minutos
    cache_key = f'category_patterns_{user.id}_{days}'
    cached_result = cache.get(cache_key)
    if cached_result:
        return cached_result
    
    try:
        start_date = timezone.now().date() - timedelta(days=days)
        
        snapshots = UserDailySnapshot.objects.filter(
            user=user,
            snapshot_date__gte=start_date
        ).order_by('snapshot_date')
        
        if not snapshots.exists():
            result = {'has_data': False}
            cache.set(cache_key, result, 900)  # 15 minutos
            return result
        
        # Análise por categoria
        category_analysis = {}
        
        for snapshot in snapshots:
            if not hasattr(snapshot, 'category_spending') or not snapshot.category_spending:
                continue
                
            for cat, data in snapshot.category_spending.items():
                if cat not in category_analysis:
                    category_analysis[cat] = {
                        'total': 0,
                        'count': 0,
                        'daily_values': [],
                        'days_with_spending': 0,
                    }
                
                category_analysis[cat]['total'] += data.get('total', 0)
                category_analysis[cat]['count'] += data.get('count', 0)
                category_analysis[cat]['daily_values'].append(data.get('total', 0))
                if data.get('total', 0) > 0:
                    category_analysis[cat]['days_with_spending'] += 1
        
        # Calcular estatísticas e sugestões
        recommendations = []
        
        for cat, stats in category_analysis.items():
            avg_daily = stats['total'] / len(snapshots) if len(snapshots) > 0 else 0
            max_daily = max(stats['daily_values']) if stats['daily_values'] else 0
            
            stats['average_daily'] = avg_daily
            stats['max_daily'] = max_daily
            stats['frequency'] = (stats['days_with_spending'] / len(snapshots)) * 100
            
            # Identificar categorias problemáticas
            if avg_daily > 50 and stats['frequency'] > 70:  # Gasto alto e frequente
                recommendations.append({
                    'category': cat,
                    'type': 'CATEGORY_LIMIT',
                    'reason': 'Categoria com gasto alto e frequente',
                    'suggested_limit': stats['total'] * 0.9,  # 10% de redução
                    'priority': 'HIGH',
                })
            elif avg_daily > 30 and stats['frequency'] > 50:  # Gasto médio frequente
                recommendations.append({
                    'category': cat,
                    'type': 'CATEGORY_REDUCTION',
                    'reason': 'Categoria com potencial de otimização',
                    'suggested_reduction_percent': 15,
                    'priority': 'MEDIUM',
                })
        
        # Ordenar por prioridade
        priority_order = {'HIGH': 0, 'MEDIUM': 1, 'LOW': 2}
        recommendations.sort(key=lambda x: priority_order.get(x.get('priority', 'LOW'), 2))
        
        result = {
            'has_data': True,
            'period_days': days,
            'categories': category_analysis,
            'recommendations': recommendations[:5],  # Top 5
            'total_categories': len(category_analysis),
        }
        
        cache.set(cache_key, result, 900)  # Cache por 15 minutos
        return result
        
    except Exception as e:
        logger.error(f"Erro ao analisar padrões de categoria para user {user.id}: {e}")
        return {
            'has_data': False,
            'error': str(e),
            'recommendations': []
        }


def analyze_tier_progression(user):
    """
    Analisa a progressão do usuário através das faixas (tiers).
    
    Determina:
    - Tier atual (BEGINNER, INTERMEDIATE, ADVANCED)
    - Progresso dentro do tier
    - Próximos marcos
    - Missões recomendadas para o tier
    
    Args:
        user: Usuário a ser analisado
    
    Returns:
        dict: Análise completa de tier e progressão
    """
    from django.core.cache import cache
    
    # Validação
    if not user:
        return {'error': 'Usuário inválido'}
    
    # Cache de 10 minutos
    cache_key = f'tier_progression_{user.id}'
    cached_result = cache.get(cache_key)
    if cached_result:
        return cached_result
    
    try:
        profile = user.userprofile
        level = profile.level
        xp = profile.experience_points
        
        # Definir tiers baseados em níveis
        if level <= 5:
            tier = 'BEGINNER'
            tier_min_level = 1
            tier_max_level = 5
            next_tier = 'INTERMEDIATE'
        elif level <= 15:
            tier = 'INTERMEDIATE'
            tier_min_level = 6
            tier_max_level = 15
            next_tier = 'ADVANCED'
        else:
            tier = 'ADVANCED'
            tier_min_level = 16
            tier_max_level = None  # Sem limite superior
            next_tier = None
        
        # Calcular XP necessário para próximo nível
        next_level_xp = profile.next_level_threshold
        current_level_xp = 150 + (level - 2) * 50 if level > 1 else 0
        xp_in_level = xp - current_level_xp
        xp_needed_for_next = next_level_xp - xp
        
        # Progresso dentro do tier
        if tier_max_level:
            levels_in_tier = tier_max_level - tier_min_level + 1
            current_position = level - tier_min_level + 1
            tier_progress = (current_position / levels_in_tier) * 100
        else:
            tier_progress = 100  # Tier ADVANCED não tem limite
        
        # Missões recomendadas por tier
        mission_focus = {
            'BEGINNER': [
                {'type': 'CONSISTENCY', 'description': 'Registrar transações diariamente'},
                {'type': 'SNAPSHOT', 'description': 'Alcançar TPS de 15%'},
                {'type': 'ONBOARDING', 'description': 'Completar primeiras transações'},
            ],
            'INTERMEDIATE': [
                {'type': 'TEMPORAL', 'description': 'Manter TPS > 20% por 30 dias'},
                {'type': 'CATEGORY_LIMIT', 'description': 'Controlar gastos por categoria'},
                {'type': 'SAVINGS_INCREASE', 'description': 'Aumentar poupança em R$ 500'},
            ],
            'ADVANCED': [
                {'type': 'CATEGORY_REDUCTION', 'description': 'Reduzir categoria em 15%'},
                {'type': 'GOAL_PROGRESS', 'description': 'Completar 80% de uma meta'},
                {'type': 'TEMPORAL', 'description': 'Manter TPS > 30% por 90 dias'},
            ],
        }
        
        result = {
            'tier': tier,
            'level': level,
            'xp': xp,
            'next_level_xp': next_level_xp,
            'xp_needed': xp_needed_for_next,
            'xp_progress_in_level': (xp_in_level / (next_level_xp - current_level_xp) * 100) if next_level_xp > current_level_xp else 100,
            'tier_range': {
                'min': tier_min_level,
                'max': tier_max_level,
            },
            'tier_progress': tier_progress,
            'next_tier': next_tier,
            'recommended_mission_types': mission_focus.get(tier, []),
            'tier_description': _get_tier_description(tier),
        }
        
        cache.set(cache_key, result, 600)  # Cache por 10 minutos
        return result
        
    except Exception as e:
        logger.error(f"Erro ao analisar tier progression para user {user.id}: {e}")
        return {
            'error': str(e),
            'tier': 'BEGINNER',
            'level': 1,
            'xp': 0,
            'next_level_xp': 100,
            'xp_needed': 100,
            'xp_progress_in_level': 0,
            'tier_range': {'min': 1, 'max': 5},
            'tier_progress': 0,
            'next_tier': 'INTERMEDIATE',
            'recommended_mission_types': [],
            'tier_description': 'Iniciante - Aprendendo os fundamentos da educação financeira',
        }


def _get_tier_description(tier):
    """Retorna descrição do tier."""
    descriptions = {
        'BEGINNER': 'Iniciante - Aprendendo os fundamentos da educação financeira',
        'INTERMEDIATE': 'Intermediário - Desenvolvendo hábitos financeiros sólidos',
        'ADVANCED': 'Avançado - Dominando estratégias financeiras complexas',
    }
    return descriptions.get(tier, '')


def get_mission_distribution_analysis(user):
    """
    Analisa a distribuição de missões do usuário para balancear geração.
    
    Evita gerar muitas missões do mesmo tipo e identifica lacunas.
    
    Args:
        user: Usuário a ser analisado
    
    Returns:
        dict: Análise de distribuição com recomendações
    """
    from django.core.cache import cache
    
    # Validação
    if not user:
        return {'error': 'Usuário inválido', 'total_missions': 0}
    
    # Cache de 10 minutos
    cache_key = f'mission_distribution_{user.id}'
    cached_result = cache.get(cache_key)
    if cached_result:
        return cached_result
    
    try:
        # Contar missões por tipo
        mission_counts = MissionProgress.objects.filter(
            user=user
        ).values('mission__mission_type').annotate(
            total=Count('id'),
            active=Count('id', filter=Q(status='ACTIVE')),
            completed=Count('id', filter=Q(status='COMPLETED')),
            failed=Count('id', filter=Q(status='FAILED')),
        )
        
        distribution = {item['mission__mission_type']: item for item in mission_counts}
        
        # Contar por validation_type
        validation_counts = MissionProgress.objects.filter(
            user=user
        ).values('mission__validation_type').annotate(
            total=Count('id'),
            active=Count('id', filter=Q(status='ACTIVE')),
            completed=Count('id', filter=Q(status='COMPLETED')),
        )
        
        validation_distribution = {item['mission__validation_type']: item for item in validation_counts}
        
        # Identificar tipos subutilizados
        all_mission_types = ['ONBOARDING', 'TPS_IMPROVEMENT', 'RDR_REDUCTION', 'ILI_BUILDING', 'ADVANCED']
        all_validation_types = ['SNAPSHOT', 'TEMPORAL', 'CATEGORY_REDUCTION', 'CATEGORY_LIMIT', 
                               'GOAL_PROGRESS', 'SAVINGS_INCREASE', 'CONSISTENCY']
        
        underutilized_mission_types = []
        underutilized_validation_types = []
        
        for mtype in all_mission_types:
            if mtype not in distribution or distribution[mtype]['total'] < 3:
                underutilized_mission_types.append(mtype)
        
        for vtype in all_validation_types:
            if vtype not in validation_distribution or validation_distribution[vtype]['total'] < 2:
                underutilized_validation_types.append(vtype)
        
        # Taxa de sucesso por tipo
        success_rates = {}
        for mtype, data in distribution.items():
            if data['total'] > 0:
                success_rates[mtype] = (data['completed'] / data['total']) * 100
        
        # Recomendar balanceamento
        recommendations = []
        
        # Se tem muitas missões ativas de um tipo
        for mtype, data in distribution.items():
            if data['active'] > 5:
                recommendations.append({
                    'action': 'REDUCE',
                    'type': mtype,
                    'reason': f'Muitas missões ativas do tipo {mtype}',
                })
        
        # Se tem tipos subutilizados
        for mtype in underutilized_mission_types[:3]:  # Top 3
            recommendations.append({
                'action': 'INCREASE',
                'type': mtype,
                'reason': f'Tipo {mtype} pouco explorado',
            })
        
        result = {
            'mission_type_distribution': distribution,
            'validation_type_distribution': validation_distribution,
            'underutilized_mission_types': underutilized_mission_types,
            'underutilized_validation_types': underutilized_validation_types,
            'success_rates': success_rates,
            'recommendations': recommendations,
            'total_missions': sum(d['total'] for d in distribution.values()) if distribution else 0,
            'active_missions': sum(d['active'] for d in distribution.values()) if distribution else 0,
            'completed_missions': sum(d['completed'] for d in distribution.values()) if distribution else 0,
        }
        
        cache.set(cache_key, result, 600)  # Cache por 10 minutos
        return result
        
    except Exception as e:
        logger.error(f"Erro ao analisar distribuição de missões para user {user.id}: {e}")
        return {
            'error': str(e),
            'mission_type_distribution': {},
            'validation_type_distribution': {},
            'underutilized_mission_types': [],
            'underutilized_validation_types': [],
            'success_rates': {},
            'recommendations': [],
            'total_missions': 0,
            'active_missions': 0,
            'completed_missions': 0,
        }


def get_comprehensive_mission_context(user):
    """
    Retorna contexto COMPLETO para geração de missões pela IA.
    
    Combina todas as análises em um único contexto rico.
    Usa cache de 30 minutos para evitar cálculos repetidos.
    
    Args:
        user: Usuário para análise
    
    Returns:
        dict: Contexto completo com todas as informações necessárias
    """
    from django.core.cache import cache
    
    # Tentar obter do cache
    cache_key = f'mission_context_{user.id}'
    cached_context = cache.get(cache_key)
    if cached_context:
        logger.debug(f"Usando contexto em cache para usuário {user.id}")
        return cached_context
    
    logger.info(f"Gerando novo contexto para usuário {user.id}")
    
    # Obter todas as análises com tratamento de erros
    try:
        evolution = analyze_user_evolution(user, days=90)
    except Exception as e:
        logger.error(f"Erro ao analisar evolução: {e}")
        evolution = {'has_data': False, 'message': str(e)}
    
    try:
        category_patterns = analyze_category_patterns(user, days=90)
    except Exception as e:
        logger.error(f"Erro ao analisar categorias: {e}")
        category_patterns = {'has_data': False, 'recommendations': []}
    
    try:
        tier_info = analyze_tier_progression(user)
    except Exception as e:
        logger.error(f"Erro ao analisar tier: {e}")
        tier_info = {
            'tier': 'BEGINNER',
            'level': 1,
            'xp': 0,
            'next_level_xp': 100,
            'xp_needed': 100,
            'xp_progress_in_level': 0,
            'tier_range': {'min': 1, 'max': 5},
            'tier_progress': 0,
            'next_tier': 'INTERMEDIATE',
            'recommended_mission_types': [],
            'tier_description': 'Iniciante'
        }
    
    try:
        distribution = get_mission_distribution_analysis(user)
    except Exception as e:
        logger.error(f"Erro ao analisar distribuição: {e}")
        distribution = {
            'total_missions': 0,
            'active_missions': 0,
            'completed_missions': 0,
            'underutilized_mission_types': [],
            'underutilized_validation_types': [],
            'success_rates': {}
        }
    
    # Summary atual com fallback
    try:
        summary = calculate_summary(user)
    except Exception as e:
        logger.error(f"Erro ao calcular summary: {e}")
        summary = {
            'tps': Decimal('0'),
            'rdr': Decimal('0'),
            'ili': Decimal('0'),
            'total_income': Decimal('0'),
            'total_expense': Decimal('0')
        }
    
    # Missões recentes
    recent_completed = MissionProgress.objects.filter(
        user=user,
        status='COMPLETED'
    ).order_by('-completed_at')[:5]
    
    recent_failed = MissionProgress.objects.filter(
        user=user,
        status='FAILED'
    ).order_by('-updated_at')[:3]
    
    # Determinar foco recomendado com base em múltiplas análises
    recommended_focus = []
    
    if evolution.get('has_data'):
        if 'TPS_BAIXO' in evolution.get('problems', []):
            recommended_focus.append('SAVINGS')
        if 'RDR_ALTO' in evolution.get('problems', []):
            recommended_focus.append('DEBT')
        if 'BAIXA_CONSISTENCIA' in evolution.get('problems', []):
            recommended_focus.append('CONSISTENCY')
    
    # Adicionar categorias problemáticas
    if category_patterns.get('has_data') and category_patterns.get('recommendations'):
        recommended_focus.append('CATEGORY_CONTROL')
    
    # Se não tem foco específico, usar tier
    if not recommended_focus:
        recommended_focus.append('TIER_PROGRESSION')
    
    context = {
        'user_id': user.id,
        'username': user.username,
        
        # Tier e Progressão
        'tier': tier_info,
        
        # Indicadores atuais
        'current_indicators': {
            'tps': float(summary.get('tps', 0)),
            'rdr': float(summary.get('rdr', 0)),
            'ili': float(summary.get('ili', 0)),
            'total_income': float(summary.get('total_income', 0)),
            'total_expense': float(summary.get('total_expense', 0)),
        },
        
        # Evolução histórica
        'evolution': evolution,
        
        # Padrões de categoria
        'category_patterns': category_patterns,
        
        # Distribuição de missões
        'mission_distribution': distribution,
        
        # Missões recentes
        'recent_completed': [
            {
                'title': m.mission.title,
                'type': m.mission.mission_type,
                'validation_type': m.mission.validation_type,
                'completed_at': m.completed_at.isoformat() if m.completed_at else None,
            }
            for m in recent_completed
        ],
        'recent_failed': [
            {
                'title': m.mission.title,
                'type': m.mission.mission_type,
                'reason': 'expired' if m.started_at and 
                         (timezone.now() - m.started_at).days > m.mission.duration_days 
                         else 'abandoned',
            }
            for m in recent_failed
        ],
        
        # Foco recomendado
        'recommended_focus': recommended_focus,
        
        # Flags especiais
        'flags': {
            'is_new_user': tier_info.get('level', 1) <= 2,
            'has_low_consistency': evolution.get('consistency', {}).get('rate', 100) < 50 if evolution.get('has_data') else False,
            'needs_category_work': len(category_patterns.get('recommendations', [])) > 0,
            'mission_imbalance': len(distribution.get('underutilized_mission_types', [])) > 3,
        },
    }
    
    # Cachear por 30 minutos
    cache.set(cache_key, context, timeout=1800)
    logger.debug(f"Contexto cacheado para usuário {user.id} (30 min)")
    
    return context


# ============================================================================
# ACHIEVEMENT VALIDATION SYSTEM
# ============================================================================

def check_achievements_for_user(user, event_type='generic'):
    """
    Valida e desbloqueia conquistas automaticamente para o usuário.
    
    Chamada de:
    - Signals: transaction_created, mission_completed, goal_completed
    - Celery tasks: daily_streak_check
    
    Args:
        user: Usuário para validar conquistas
        event_type: Tipo de evento que disparou a validação
                   ('transaction', 'mission', 'goal', 'streak', 'generic')
    
    Returns:
        list: Lista de conquistas desbloqueadas nesta validação
    """
    from .models import Achievement, UserAchievement
    
    # Buscar conquistas já desbloqueadas para excluir
    unlocked_ids = UserAchievement.objects.filter(
        user=user, 
        is_unlocked=True
    ).values_list('achievement_id', flat=True)
    
    # Buscar conquistas ativas que ainda não foram desbloqueadas
    achievements = Achievement.objects.filter(
        is_active=True
    ).exclude(id__in=unlocked_ids)
    
    # Filtrar por categoria relevante ao evento (otimização)
    if event_type == 'transaction':
        achievements = achievements.filter(category='FINANCIAL')
    elif event_type == 'mission':
        achievements = achievements.filter(category='MISSION')
    elif event_type == 'streak':
        achievements = achievements.filter(category='STREAK')
    
    newly_unlocked = []
    
    for achievement in achievements:
        criteria = achievement.criteria
        
        # Verificar se critérios foram atendidos
        if check_criteria_met(user, criteria):
            # Buscar ou criar UserAchievement
            user_achievement, created = UserAchievement.objects.get_or_create(
                user=user,
                achievement=achievement,
                defaults={
                    'progress': criteria.get('target', 100),
                    'progress_max': criteria.get('target', 100),
                }
            )
            
            # Desbloquear conquista
            if user_achievement.unlock():
                newly_unlocked.append(achievement)
                logger.info(
                    f"Conquista '{achievement.title}' desbloqueada para {user.username} "
                    f"(XP: +{achievement.xp_reward}, event: {event_type})"
                )
    
    return newly_unlocked


def check_criteria_met(user, criteria):
    """
    Verifica se o usuário atende os critérios de uma conquista.
    
    Tipos de critérios suportados:
    1. count: Contagem de elementos (transações, missões, amigos, etc.)
       Exemplo: {"type": "count", "target": 10, "metric": "transactions"}
    
    2. value: Valor numérico de indicadores (TPS, RDR, ILI, savings, etc.)
       Exemplo: {"type": "value", "target": 30, "metric": "tps", "duration": 90}
    
    3. streak: Dias consecutivos de atividade
       Exemplo: {"type": "streak", "target": 7, "metric": "login"}
    
    Args:
        user: Usuário para validar
        criteria: Dict com type, target, metric, duration (opcional)
    
    Returns:
        bool: True se critérios atendidos, False caso contrário
    """
    if not criteria or not isinstance(criteria, dict):
        return False
    
    ctype = criteria.get('type')
    target = criteria.get('target', 0)
    metric = criteria.get('metric', '')
    duration = criteria.get('duration')  # Opcional: dias de duração
    
    # ========================================================================
    # TYPE: COUNT - Contagem de elementos
    # ========================================================================
    if ctype == 'count':
        if metric == 'transactions':
            # Total de transações do usuário
            count = Transaction.objects.filter(user=user).count()
            return count >= target
        
        elif metric == 'income_transactions':
            # Total de transações de receita
            count = Transaction.objects.filter(
                user=user, 
                type=Transaction.TransactionType.INCOME
            ).count()
            return count >= target
        
        elif metric == 'expense_transactions':
            # Total de transações de despesa
            count = Transaction.objects.filter(
                user=user, 
                type=Transaction.TransactionType.EXPENSE
            ).count()
            return count >= target
        
        elif metric == 'missions':
            # Total de missões completadas
            count = MissionProgress.objects.filter(
                user=user, 
                status='COMPLETED'
            ).count()
            return count >= target
        
        elif metric == 'goals':
            # Total de metas concluídas (current_amount >= target_amount)
            count = Goal.objects.filter(
                user=user,
                current_amount__gte=F('target_amount')
            ).count()
            return count >= target
        
        elif metric == 'friends':
            # Total de amigos
            from .models import Friendship
            count = Friendship.objects.filter(
                Q(from_user=user, status=Friendship.FriendshipStatus.ACCEPTED) |
                Q(to_user=user, status=Friendship.FriendshipStatus.ACCEPTED)
            ).count()
            return count >= target
        
        elif metric == 'categories':
            # Total de categorias criadas pelo usuário
            count = Category.objects.filter(
                user=user,
                is_default=False
            ).count()
            return count >= target
    
    # ========================================================================
    # TYPE: VALUE - Valores numéricos (indicadores, totais, etc.)
    # ========================================================================
    elif ctype == 'value':
        if metric == 'tps':
            # Taxa de Poupança Pessoal
            summary = calculate_summary(user)
            tps = summary.get('tps', Decimal('0'))
            
            # Se duration especificado, validar período
            if duration:
                # TODO: Implementar validação de TPS em período específico
                # Por enquanto, usar TPS atual
                pass
            
            return tps >= target
        
        elif metric == 'ili':
            # Índice de Liquidez Imediata
            summary = calculate_summary(user)
            ili = summary.get('ili', Decimal('0'))
            return ili >= target
        
        elif metric == 'rdr':
            # Razão de Despesas Recorrentes
            summary = calculate_summary(user)
            rdr = summary.get('rdr', Decimal('0'))
            # RDR: menor é melhor (meta é manter abaixo de target)
            return rdr <= target
        
        elif metric == 'total_income':
            # Total de receitas
            total = Transaction.objects.filter(
                user=user,
                type=Transaction.TransactionType.INCOME
            ).aggregate(total=Sum('amount'))['total'] or Decimal('0')
            return total >= target
        
        elif metric == 'total_expense':
            # Total de despesas
            total = Transaction.objects.filter(
                user=user,
                type=Transaction.TransactionType.EXPENSE
            ).aggregate(total=Sum('amount'))['total'] or Decimal('0')
            return total >= target
        
        elif metric == 'savings':
            # Saldo da reserva de emergência
            reserve_transactions = Transaction.objects.filter(
                user=user, 
                category__group=Category.CategoryGroup.SAVINGS
            ).values("type").annotate(total=Sum("amount"))
            
            reserve_deposits = Decimal("0")
            reserve_withdrawals = Decimal("0")
            
            for item in reserve_transactions:
                tx_type = item["type"]
                total = _decimal(item["total"])
                if tx_type == Transaction.TransactionType.INCOME:
                    reserve_deposits = total
                else:
                    reserve_withdrawals = total
            
            net_reserve = reserve_deposits - reserve_withdrawals
            return net_reserve >= target
        
        elif metric == 'xp':
            # Experiência total
            profile, _ = UserProfile.objects.get_or_create(user=user)
            return profile.experience_points >= target
        
        elif metric == 'level':
            # Nível do usuário
            profile, _ = UserProfile.objects.get_or_create(user=user)
            return profile.level >= target
    
    # ========================================================================
    # TYPE: STREAK - Dias consecutivos de atividade
    # ========================================================================
    elif ctype == 'streak':
        # TODO: Implementar sistema de streak tracking
        # Por enquanto, retornar False (será implementado com Celery task)
        
        # Exemplo de implementação futura:
        # if metric == 'login':
        #     streak = get_login_streak(user)
        #     return streak >= target
        # elif metric == 'transaction':
        #     streak = get_transaction_streak(user)
        #     return streak >= target
        # elif metric == 'mission':
        #     streak = get_mission_streak(user)
        #     return streak >= target
        
        return False
    
    # Tipo de critério não reconhecido
    return False


def update_achievement_progress(user, achievement_id):
    """
    Atualiza o progresso de uma conquista específica para o usuário.
    
    Útil para mostrar progresso parcial antes do unlock completo.
    
    Args:
        user: Usuário
        achievement_id: ID da conquista
    
    Returns:
        UserAchievement atualizado ou None
    """
    from .models import Achievement, UserAchievement
    
    try:
        achievement = Achievement.objects.get(id=achievement_id, is_active=True)
    except Achievement.DoesNotExist:
        return None
    
    # Buscar ou criar UserAchievement
    user_achievement, created = UserAchievement.objects.get_or_create(
        user=user,
        achievement=achievement,
        defaults={
            'progress': 0,
            'progress_max': achievement.criteria.get('target', 100),
        }
    )
    
    # Se já desbloqueada, não atualizar
    if user_achievement.is_unlocked:
        return user_achievement
    
    # Calcular progresso atual baseado nos critérios
    criteria = achievement.criteria
    ctype = criteria.get('type')
    metric = criteria.get('metric')
    target = criteria.get('target', 100)
    
    current_progress = 0
    
    # COUNT types
    if ctype == 'count':
        if metric == 'transactions':
            current_progress = Transaction.objects.filter(user=user).count()
        elif metric == 'missions':
            current_progress = MissionProgress.objects.filter(user=user, status='COMPLETED').count()
        elif metric == 'goals':
            # Metas concluídas: current_amount >= target_amount
            current_progress = Goal.objects.filter(
                user=user,
                current_amount__gte=F('target_amount')
            ).count()
        elif metric == 'friends':
            from .models import Friendship
            current_progress = Friendship.objects.filter(
                Q(from_user=user, status=Friendship.FriendshipStatus.ACCEPTED) |
                Q(to_user=user, status=Friendship.FriendshipStatus.ACCEPTED)
            ).count()
    
    # VALUE types
    elif ctype == 'value':
        if metric in ['tps', 'ili', 'rdr']:
            summary = calculate_summary(user)
            current_progress = int(summary.get(metric, Decimal('0')))
        elif metric == 'xp':
            profile, _ = UserProfile.objects.get_or_create(user=user)
            current_progress = profile.experience_points
        elif metric == 'level':
            profile, _ = UserProfile.objects.get_or_create(user=user)
            current_progress = profile.level
    
    # Atualizar progresso
    user_achievement.progress = min(current_progress, target)
    user_achievement.progress_max = target
    user_achievement.save(update_fields=['progress', 'progress_max'])
    
    return user_achievement
