from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Dict

from django.db.models import F, Sum
from django.db.models.functions import Coalesce

from ..models import Goal, Transaction
from .base import _decimal


def update_goal_progress(goal) -> None:
    """
    Atualiza o progresso de uma meta baseado nas transações relacionadas.
    Chamado automaticamente após criar/atualizar/deletar transação
    quando goal.auto_update=True.
    """
    if not goal.auto_update:
        return
    
    transactions = goal.get_related_transactions()
    
    total = _decimal(
        transactions.aggregate(total=Coalesce(Sum('amount'), Decimal('0')))['total']
    )
    
    total_with_initial = total + goal.initial_amount
    
    if goal.is_reduction_goal:
        if total < goal.target_amount:
            goal.current_amount = goal.target_amount - total
        else:
            goal.current_amount = Decimal('0.00')
    else:
        goal.current_amount = total_with_initial
    
    goal.save(update_fields=['current_amount', 'updated_at'])


def update_all_active_goals(user) -> None:
    """
    Atualiza todas as metas ativas do usuário que têm auto_update=True.
    Chamado após criar/atualizar/deletar qualquer transação.
    """
    goals = Goal.objects.filter(user=user, auto_update=True)
    for goal in goals:
        update_goal_progress(goal)


def get_goal_insights(goal) -> Dict[str, str]:
    """Gera insights e sugestões para uma meta específica."""
    insights = {
        'status': '',
        'message': '',
        'suggestion': ''
    }
    
    progress = goal.progress_percentage
    
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
    
    if goal.deadline:
        today = date.today()
        days_remaining = (goal.deadline - today).days
        
        if days_remaining < 0:
            insights['message'] += f' (Prazo expirou há {abs(days_remaining)} dias)'
        elif days_remaining <= 7:
            insights['message'] += f' (Faltam {days_remaining} dias!)'
        elif days_remaining <= 30:
            insights['message'] += f' (Faltam {days_remaining} dias)'
    
    if goal.goal_type == Goal.GoalType.CATEGORY_EXPENSE and goal.is_reduction_goal:
        if progress < 50 and goal.tracking_period == Goal.TrackingPeriod.MONTHLY:
            insights['suggestion'] = f'Tente reduzir gastos em {goal.target_category.name}. ' + insights['suggestion']
    
    return insights
