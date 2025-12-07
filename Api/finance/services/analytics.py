from __future__ import annotations

from decimal import Decimal
from typing import Dict, List

from django.db.models import Avg, Count, F, Min, Max, Q, Sum
from django.utils import timezone

from ..models import (
    Category, Mission, MissionProgress, Transaction, UserProfile
)
from .base import _decimal, logger
from .indicators import calculate_summary


def analyze_user_evolution(user, days=90):
    from datetime import timedelta
    from django.db.models.functions import TruncDate
    
    start_date = timezone.now().date() - timedelta(days=days)
    
    transactions = Transaction.objects.filter(
        user=user,
        date__gte=start_date
    )
    
    if not transactions.exists():
        return {
            'has_data': False,
            'message': 'Dados insuficientes para análise (nenhuma transação no período)'
        }
    
    current_summary = calculate_summary(user)
    
    daily_data = transactions.annotate(
        day=TruncDate('date')
    ).values('day').annotate(
        income=Sum('amount', filter=Q(type=Transaction.TransactionType.INCOME)),
        expense=Sum('amount', filter=Q(type=Transaction.TransactionType.EXPENSE)),
        tx_count=Count('id')
    ).order_by('day')
    
    days_with_transactions = daily_data.count()
    total_days = (timezone.now().date() - start_date).days or 1
    consistency_rate = (days_with_transactions / total_days) * 100
    
    category_spending = transactions.filter(
        type=Transaction.TransactionType.EXPENSE
    ).values('category__name').annotate(
        total=Sum('amount')
    ).order_by('-total')
    
    all_category_spending = {
        item['category__name']: float(item['total'])
        for item in category_spending
        if item['category__name']
    }
    
    problem_category = list(all_category_spending.keys())[0] if all_category_spending else None
    
    tps = float(current_summary.get('tps', 0))
    rdr = float(current_summary.get('rdr', 0))
    ili = float(current_summary.get('ili', 0))
    
    problems = []
    if tps < 15:
        problems.append('TPS_BAIXO')
    if rdr > 40:
        problems.append('RDR_ALTO')
    if ili < 3:
        problems.append('ILI_BAIXO')
    if consistency_rate < 50:
        problems.append('BAIXA_CONSISTENCIA')
    
    strengths = []
    if tps >= 20:
        strengths.append('TPS_BOM')
    if rdr <= 30:
        strengths.append('RDR_BOM')
    if ili >= 6:
        strengths.append('ILI_BOM')
    if consistency_rate > 80:
        strengths.append('ALTA_CONSISTENCIA')
    
    return {
        'has_data': True,
        'period_days': days,
        'transactions_count': transactions.count(),
        'tps': {
            'current': tps,
            'status': 'bom' if tps >= 20 else 'atenção' if tps >= 10 else 'crítico',
        },
        'rdr': {
            'current': rdr,
            'status': 'bom' if rdr <= 30 else 'atenção' if rdr <= 40 else 'crítico',
        },
        'ili': {
            'current': ili,
            'status': 'bom' if ili >= 6 else 'atenção' if ili >= 3 else 'crítico',
        },
        'categories': {
            'most_spending': problem_category,
            'all_spending': all_category_spending,
        },
        'consistency': {
            'rate': consistency_rate,
            'days_with_transactions': days_with_transactions,
            'total_days': total_days,
        },
        'problems': problems,
        'strengths': strengths,
    }


def analyze_category_patterns(user, days=90):
    from datetime import timedelta
    from django.core.cache import cache
    from django.db.models.functions import TruncDate
    
    if not user or days <= 0:
        return {'has_data': False, 'error': 'Parâmetros inválidos'}
    
    cache_key = f'category_patterns_{user.id}_{days}'
    cached_result = cache.get(cache_key)
    if cached_result:
        return cached_result
    
    try:
        start_date = timezone.now().date() - timedelta(days=days)
        
        expense_transactions = Transaction.objects.filter(
            user=user,
            type=Transaction.TransactionType.EXPENSE,
            date__gte=start_date
        )
        
        if not expense_transactions.exists():
            result = {'has_data': False}
            cache.set(cache_key, result, 900)
            return result
        
        daily_category_data = expense_transactions.annotate(
            day=TruncDate('date')
        ).values('day', 'category__name').annotate(
            total=Sum('amount'),
            count=Count('id')
        ).order_by('day', 'category__name')
        
        total_days = (timezone.now().date() - start_date).days or 1
        
        category_analysis = {}
        
        for item in daily_category_data:
            cat = item['category__name']
            if not cat:
                continue
                
            if cat not in category_analysis:
                category_analysis[cat] = {
                    'total': 0,
                    'count': 0,
                    'daily_values': [],
                    'days_with_spending': 0,
                }
            
            amount = float(item['total']) if item['total'] else 0
            category_analysis[cat]['total'] += amount
            category_analysis[cat]['count'] += item['count']
            category_analysis[cat]['daily_values'].append(amount)
            if amount > 0:
                category_analysis[cat]['days_with_spending'] += 1
        
        recommendations = []
        
        for cat, stats in category_analysis.items():
            avg_daily = stats['total'] / total_days if total_days > 0 else 0
            max_daily = max(stats['daily_values']) if stats['daily_values'] else 0
            
            stats['average_daily'] = avg_daily
            stats['max_daily'] = max_daily
            stats['frequency'] = (stats['days_with_spending'] / total_days) * 100
            
            if avg_daily > 50 and stats['frequency'] > 70:
                recommendations.append({
                    'category': cat,
                    'type': 'CATEGORY_LIMIT',
                    'reason': 'Categoria com gasto alto e frequente',
                    'suggested_limit': stats['total'] * 0.9,
                    'priority': 'HIGH',
                })
            elif avg_daily > 30 and stats['frequency'] > 50:
                recommendations.append({
                    'category': cat,
                    'type': 'CATEGORY_REDUCTION',
                    'reason': 'Categoria com potencial de otimização',
                    'suggested_reduction_percent': 15,
                    'priority': 'MEDIUM',
                })
        
        priority_order = {'HIGH': 0, 'MEDIUM': 1, 'LOW': 2}
        recommendations.sort(key=lambda x: priority_order.get(x.get('priority', 'LOW'), 2))
        
        result = {
            'has_data': True,
            'period_days': days,
            'categories': category_analysis,
            'recommendations': recommendations[:5],
            'total_categories': len(category_analysis),
        }
        
        cache.set(cache_key, result, 900)
        return result
        
    except Exception as e:
        logger.error(f"Erro ao analisar padrões de categoria para user {user.id}: {e}")
        return {
            'has_data': False,
            'error': str(e),
            'recommendations': []
        }


def analyze_tier_progression(user):
    from django.core.cache import cache
    
    if not user:
        return {'error': 'Usuário inválido'}
    
    cache_key = f'tier_progression_{user.id}'
    cached_result = cache.get(cache_key)
    if cached_result:
        return cached_result
    
    try:
        profile = user.userprofile
        level = profile.level
        xp = profile.experience_points
        
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
            tier_max_level = None
            next_tier = None
        
        next_level_xp = profile.next_level_threshold
        current_level_xp = 150 + (level - 2) * 50 if level > 1 else 0
        xp_in_level = xp - current_level_xp
        xp_needed_for_next = next_level_xp - xp
        
        if tier_max_level:
            levels_in_tier = tier_max_level - tier_min_level + 1
            current_position = level - tier_min_level + 1
            tier_progress = (current_position / levels_in_tier) * 100
        else:
            tier_progress = 100
        
        mission_focus = {
            'BEGINNER': [
                {'type': 'CONSISTENCY', 'description': 'Registrar transações diariamente'},
                {'type': 'SNAPSHOT', 'description': 'Alcançar TPS de 15%'},
                {'type': 'ONBOARDING', 'description': 'Completar primeiras transações'},
            ],
            'INTERMEDIATE': [
                {'type': 'INDICATOR_THRESHOLD', 'description': 'Alcançar TPS > 20%'},
                {'type': 'CATEGORY_LIMIT', 'description': 'Controlar gastos por categoria'},
                {'type': 'SAVINGS_INCREASE', 'description': 'Aumentar poupança em R$ 500'},
            ],
            'ADVANCED': [
                {'type': 'CATEGORY_REDUCTION', 'description': 'Reduzir categoria em 15%'},
                {'type': 'INDICATOR_THRESHOLD', 'description': 'Alcançar TPS > 30%'},
                {'type': 'MULTI_CRITERIA', 'description': 'Múltiplos indicadores simultaneamente'},
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
        
        cache.set(cache_key, result, 600)
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
    descriptions = {
        'BEGINNER': 'Iniciante - Aprendendo os fundamentos da educação financeira',
        'INTERMEDIATE': 'Intermediário - Desenvolvendo hábitos financeiros sólidos',
        'ADVANCED': 'Avançado - Dominando estratégias financeiras complexas',
    }
    return descriptions.get(tier, '')


def get_mission_distribution_analysis(user):
    from django.core.cache import cache
    
    if not user:
        return {'error': 'Usuário inválido', 'total_missions': 0}
    
    cache_key = f'mission_distribution_{user.id}'
    cached_result = cache.get(cache_key)
    if cached_result:
        return cached_result
    
    try:
        mission_counts = MissionProgress.objects.filter(
            user=user
        ).values('mission__mission_type').annotate(
            total=Count('id'),
            active=Count('id', filter=Q(status='ACTIVE')),
            completed=Count('id', filter=Q(status='COMPLETED')),
            failed=Count('id', filter=Q(status='FAILED')),
        )
        
        distribution = {item['mission__mission_type']: item for item in mission_counts}
        
        validation_counts = MissionProgress.objects.filter(
            user=user
        ).values('mission__validation_type').annotate(
            total=Count('id'),
            active=Count('id', filter=Q(status='ACTIVE')),
            completed=Count('id', filter=Q(status='COMPLETED')),
        )
        
        validation_distribution = {item['mission__validation_type']: item for item in validation_counts}
        
        all_mission_types = ['ONBOARDING', 'TPS_IMPROVEMENT', 'RDR_REDUCTION', 'ILI_BUILDING', 'ADVANCED']
        all_validation_types = ['SNAPSHOT', 'INDICATOR_THRESHOLD', 'CATEGORY_REDUCTION', 'CATEGORY_LIMIT', 
                               'TRANSACTION_COUNT', 'SAVINGS_INCREASE', 'CONSISTENCY']
        
        underutilized_mission_types = []
        underutilized_validation_types = []
        
        for mtype in all_mission_types:
            if mtype not in distribution or distribution[mtype]['total'] < 3:
                underutilized_mission_types.append(mtype)
        
        for vtype in all_validation_types:
            if vtype not in validation_distribution or validation_distribution[vtype]['total'] < 2:
                underutilized_validation_types.append(vtype)
        
        success_rates = {}
        for mtype, data in distribution.items():
            if data['total'] > 0:
                success_rates[mtype] = (data['completed'] / data['total']) * 100
        
        recommendations = []
        
        for mtype, data in distribution.items():
            if data['active'] > 5:
                recommendations.append({
                    'action': 'REDUCE',
                    'type': mtype,
                    'reason': f'Muitas missões ativas do tipo {mtype}',
                })
        
        for mtype in underutilized_mission_types[:3]:
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
        
        cache.set(cache_key, result, 600)
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
    from django.core.cache import cache
    
    cache_key = f'mission_context_{user.id}'
    cached_context = cache.get(cache_key)
    if cached_context:
        logger.debug(f"Usando contexto em cache para usuário {user.id}")
        return cached_context
    
    logger.info(f"Gerando novo contexto para usuário {user.id}")
    
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
    
    recent_completed = MissionProgress.objects.filter(
        user=user,
        status='COMPLETED'
    ).order_by('-completed_at')[:5]
    
    recent_failed = MissionProgress.objects.filter(
        user=user,
        status='FAILED'
    ).order_by('-updated_at')[:3]
    
    recommended_focus = []
    
    if evolution.get('has_data'):
        if 'TPS_BAIXO' in evolution.get('problems', []):
            recommended_focus.append('SAVINGS')
        if 'RDR_ALTO' in evolution.get('problems', []):
            recommended_focus.append('DEBT')
        if 'BAIXA_CONSISTENCIA' in evolution.get('problems', []):
            recommended_focus.append('CONSISTENCY')
    
    if category_patterns.get('has_data') and category_patterns.get('recommendations'):
        recommended_focus.append('CATEGORY_CONTROL')
    
    if not recommended_focus:
        recommended_focus.append('TIER_PROGRESSION')
    
    context = {
        'user_id': user.id,
        'username': user.username,
        
        'tier': tier_info,
        
        'current_indicators': {
            'tps': float(summary.get('tps', 0)),
            'rdr': float(summary.get('rdr', 0)),
            'ili': float(summary.get('ili', 0)),
            'total_income': float(summary.get('total_income', 0)),
            'total_expense': float(summary.get('total_expense', 0)),
        },
        
        'evolution': evolution,
        
        'category_patterns': category_patterns,
        
        'mission_distribution': distribution,
        
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
        
        'recommended_focus': recommended_focus,
        
        'flags': {
            'is_new_user': tier_info.get('level', 1) <= 2,
            'has_low_consistency': evolution.get('consistency', {}).get('rate', 100) < 50 if evolution.get('has_data') else False,
            'needs_category_work': len(category_patterns.get('recommendations', [])) > 0,
            'mission_imbalance': len(distribution.get('underutilized_mission_types', [])) > 3,
        },
    }
    
    cache.set(cache_key, context, timeout=1800)
    logger.debug(f"Contexto cacheado para usuário {user.id} (30 min)")
    
    return context
