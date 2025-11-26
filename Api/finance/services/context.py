from __future__ import annotations

from datetime import timedelta
from decimal import Decimal
from typing import Any, Dict, List

from django.db.models import Avg, Count, F, Sum
from django.utils import timezone

from ..models import Goal, Transaction, UserProfile
from .base import logger
from .indicators import calculate_summary


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
        current_amount__gte=F('target_amount')
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
            'category': trans.category.name if trans.category else 'Sem categoria',
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
    
    recent_spending = Transaction.objects.filter(
        user=user,
        type=Transaction.TransactionType.EXPENSE,
        date__gte=thirty_days_ago
    ).values('category__id', 'category__name').annotate(
        total=Sum('amount')
    )
    
    previous_spending = Transaction.objects.filter(
        user=user,
        type=Transaction.TransactionType.EXPENSE,
        date__gte=sixty_days_ago,
        date__lt=thirty_days_ago
    ).values('category__id', 'category__name').annotate(
        total=Sum('amount')
    )
    
    recent_dict = {item['category__id']: float(item['total']) for item in recent_spending}
    previous_dict = {item['category__id']: float(item['total']) for item in previous_spending}
    
    for cat_id, recent_total in recent_dict.items():
        previous_total = previous_dict.get(cat_id, 0)
        if previous_total > 0:
            growth_percent = ((recent_total - previous_total) / previous_total) * 100
            if growth_percent > 20:
                category_name = next(
                    (item['category__name'] for item in recent_spending if item['category__id'] == cat_id),
                    'Desconhecida'
                )
                opportunities.append({
                    'type': 'CATEGORY_GROWTH',
                    'priority': 'HIGH' if growth_percent > 50 else 'MEDIUM',
                    'description': f'Gastos em "{category_name}" aumentaram {growth_percent:.1f}%',
                    'data': {
                        'category_id': cat_id,
                        'category_name': category_name,
                        'growth_percent': growth_percent,
                        'recent_total': recent_total,
                        'previous_total': previous_total
                    }
                })
    
    fifteen_days_ago = today - timedelta(days=15)
    
    active_goals = Goal.objects.filter(
        user=user,
        deadline__gte=today
    ).exclude(
        current_amount__gte=F('target_amount')
    )
    
    for goal in active_goals:
        if goal.target_category:
            last_contribution = Transaction.objects.filter(
                user=user,
                category=goal.target_category,
                type=Transaction.TransactionType.INCOME
            ).order_by('-date').first()
        else:
            continue
        
        if not last_contribution or last_contribution.date < fifteen_days_ago:
            days_stagnant = (today - last_contribution.date).days if last_contribution else 999
            opportunities.append({
                'type': 'GOAL_STAGNANT',
                'priority': 'HIGH' if days_stagnant > 30 else 'MEDIUM',
                'description': f'Meta "{goal.title}" estagnada há {days_stagnant} dias',
                'data': {
                    'goal_id': goal.id,
                    'goal_name': goal.title,
                    'days_stagnant': days_stagnant,
                    'progress_percent': float((goal.current_amount / goal.target_amount * 100) if goal.target_amount > 0 else 0)
                }
            })
    
    summary_current = calculate_summary(user)
    profile, _ = UserProfile.objects.get_or_create(user=user)
    
    tps = float(summary_current.get('tps', Decimal('0')))
    if tps < profile.target_tps:
        gap = profile.target_tps - tps
        opportunities.append({
            'type': 'INDICATOR_BELOW_TARGET',
            'priority': 'HIGH' if gap > 10 else 'MEDIUM',
            'description': f'TPS inferior à meta: {tps:.1f}% (meta: {profile.target_tps}%)',
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
            'description': f'RDR superior à meta: {rdr:.1f}% (meta: {profile.target_rdr}%)',
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
            'description': f'ILI inferior à meta: {ili:.1f} meses (meta: {target_ili:.1f})',
            'data': {
                'indicator': 'ILI',
                'current': ili,
                'target': target_ili,
                'gap': gap
            }
        })
    
    priority_order = {'HIGH': 0, 'MEDIUM': 1, 'LOW': 2}
    opportunities.sort(key=lambda x: priority_order.get(x['priority'], 3))
    
    return opportunities
