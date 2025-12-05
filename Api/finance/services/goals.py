from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Dict, List, Optional

from django.db.models import F, Sum
from django.db.models.functions import Coalesce

from ..models import Goal, Transaction
from .base import _decimal


def calculate_initial_amount(
    user,
    goal_type: str,
    category_ids: Optional[List] = None
) -> Decimal:
    """
    Calcula o valor inicial da meta baseado nas transações do mês atual.
    
    Args:
        user: Usuário dono da meta
        goal_type: Tipo da meta (SAVINGS, EXPENSE_REDUCTION, INCOME_INCREASE, CUSTOM)
        category_ids: Lista de IDs das categorias selecionadas (opcional)
    
    Returns:
        Decimal: Valor total das transações do mês atual nas categorias relevantes
    """
    from datetime import date as date_module
    from ..models import Category
    
    today = date_module.today()
    month_start = today.replace(day=1)
    
    if goal_type == 'CUSTOM':
        return Decimal('0')
    
    base_query = Transaction.objects.filter(
        user=user,
        date__gte=month_start,
        date__lte=today
    )
    
    if goal_type == 'SAVINGS' or goal_type == 'EMERGENCY_FUND':
        if category_ids:
            query = base_query.filter(category_id__in=category_ids)
        else:
            query = base_query.filter(
                category__group__in=[
                    Category.CategoryGroup.SAVINGS,
                    Category.CategoryGroup.INVESTMENT
                ]
            )
    
    elif goal_type == 'EXPENSE_REDUCTION':
        if not category_ids:
            return Decimal('0')
        query = base_query.filter(
            type=Transaction.TransactionType.EXPENSE,
            category_id__in=category_ids
        )
    
    elif goal_type == 'INCOME_INCREASE':
        if category_ids:
            query = base_query.filter(
                type=Transaction.TransactionType.INCOME,
                category_id__in=category_ids
            )
        else:
            query = base_query.filter(type=Transaction.TransactionType.INCOME)
    
    else:
        return Decimal('0')
    
    total = query.aggregate(
        total=Coalesce(Sum('amount'), Decimal('0'))
    )['total']
    
    return _decimal(total)


def update_goal_progress(goal) -> None:
    """
    Atualiza o progresso de uma meta baseado no tipo.
    
    Tipos suportados:
    - SAVINGS: Soma transações em categorias SAVINGS/INVESTMENT ou target_categories
    - EMERGENCY_FUND: Tratado como SAVINGS (compatibilidade durante migração)
    - EXPENSE_REDUCTION: Compara gastos atuais vs baseline nas target_categories
    - INCOME_INCREASE: Compara receitas atuais vs baseline
    - CUSTOM: Não atualizado automaticamente
    """
    if goal.goal_type == Goal.GoalType.CUSTOM:
        return  # Metas CUSTOM são atualizadas manualmente
    
    if goal.goal_type == Goal.GoalType.SAVINGS:
        _update_savings_goal(goal)
    elif goal.goal_type == Goal.GoalType.EMERGENCY_FUND:
        _update_savings_goal(goal)  # Tratado como SAVINGS
    elif goal.goal_type == Goal.GoalType.EXPENSE_REDUCTION:
        _update_expense_reduction_goal(goal)
    elif goal.goal_type == Goal.GoalType.INCOME_INCREASE:
        _update_income_increase_goal(goal)


def _update_savings_goal(goal) -> None:
    """
    Atualiza metas de poupança (SAVINGS).
    
    Lógica:
    - Se target_categories definido: soma transações nessas categorias
    - Senão: soma transações em categorias SAVINGS/INVESTMENT
    - Adiciona initial_amount ao total
    """
    from ..models import Category
    
    if goal.target_categories.exists():
        # Usar categorias específicas definidas pelo usuário
        transactions = Transaction.objects.filter(
            user=goal.user,
            category__in=goal.target_categories.all()
        )
    else:
        # Usar categorias padrão: SAVINGS e INVESTMENT
        transactions = Transaction.objects.filter(
            user=goal.user,
            category__group__in=[
                Category.CategoryGroup.SAVINGS,
                Category.CategoryGroup.INVESTMENT
            ]
        )
    
    total = _decimal(
        transactions.aggregate(total=Coalesce(Sum('amount'), Decimal('0')))['total']
    )
    
    total_with_initial = total + goal.initial_amount
    goal.current_amount = total_with_initial
    
    goal.save(update_fields=['current_amount', 'updated_at'])


def _update_expense_reduction_goal(goal) -> None:
    """
    Atualiza meta de redução de gastos.
    
    Lógica:
    - Calcula gastos médios mensais nas categorias alvo nos últimos X meses
    - Compara com baseline_amount
    - Redução = baseline - gastos_atuais
    - current_amount = redução alcançada
    """
    # Verifica se há categorias alvo
    if not goal.target_categories.exists() or not goal.baseline_amount:
        return  # Sem dados suficientes
    
    from dateutil.relativedelta import relativedelta
    from django.utils import timezone
    
    today = timezone.now().date()
    period_start = today - relativedelta(months=goal.tracking_period_months)
    
    # Gastos atuais em TODAS as categorias alvo
    current_expenses = Transaction.objects.filter(
        user=goal.user,
        type=Transaction.TransactionType.EXPENSE,
        category__in=goal.target_categories.all(),  # Múltiplas categorias
        date__gte=period_start,
        date__lte=today
    ).aggregate(total=Coalesce(Sum('amount'), Decimal('0')))['total']
    
    current_expenses = _decimal(current_expenses)
    
    # Calcular dias reais no período para normalização mais precisa
    days_in_period = (today - period_start).days
    if days_in_period == 0:
        current_monthly = Decimal('0')
    else:
        # Normalizar para 30 dias (média mensal)
        current_monthly = (current_expenses / Decimal(str(days_in_period))) * Decimal('30')
    
    # Redução alcançada
    reduction = goal.baseline_amount - current_monthly
    goal.current_amount = reduction if reduction > 0 else Decimal('0')
    
    goal.save(update_fields=['current_amount', 'updated_at'])



def _update_income_increase_goal(goal) -> None:
    """
    Atualiza meta de aumento de receita.
    
    Lógica:
    - Se target_categories definido: soma receitas nessas categorias
    - Senão: soma todas as receitas
    - Calcula receitas médias mensais nos últimos X meses
    - Compara com baseline_amount
    - Aumento = receitas_atuais - baseline
    - current_amount = aumento alcançado
    """
    if not goal.baseline_amount:
        return  # Sem baseline definido
    
    from dateutil.relativedelta import relativedelta
    from django.utils import timezone
    
    today = timezone.now().date()
    period_start = today - relativedelta(months=goal.tracking_period_months)
    
    # Base query: receitas do usuário no período
    query = Transaction.objects.filter(
        user=goal.user,
        type=Transaction.TransactionType.INCOME,
        date__gte=period_start,
        date__lte=today
    )
    
    # Filtrar por categorias se definidas
    if goal.target_categories.exists():
        query = query.filter(category__in=goal.target_categories.all())
    
    current_income = query.aggregate(
        total=Coalesce(Sum('amount'), Decimal('0'))
    )['total']
    
    current_income = _decimal(current_income)
    
    # Calcular dias reais no período para normalização mais precisa
    days_in_period = (today - period_start).days
    if days_in_period == 0:
        current_monthly = Decimal('0')
    else:
        # Normalizar para 30 dias (média mensal)
        current_monthly = (current_income / Decimal(str(days_in_period))) * Decimal('30')
    
    # Aumento alcançado
    increase = current_monthly - goal.baseline_amount
    goal.current_amount = increase if increase > 0 else Decimal('0')
    
    goal.save(update_fields=['current_amount', 'updated_at'])



def update_all_active_goals(user) -> None:
    """
    Atualiza todas as metas do usuário (exceto CUSTOM).
    Chamado após criar/atualizar/deletar qualquer transação.
    """
    goals = Goal.objects.filter(user=user).exclude(goal_type=Goal.GoalType.CUSTOM)
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
    
    # Dicas específicas por tipo de meta
    if goal.goal_type == Goal.GoalType.EXPENSE_REDUCTION:
        if progress < 50:
            insights['suggestion'] = 'Revise seus gastos e identifique onde pode economizar. ' + insights['suggestion']
    elif goal.goal_type == Goal.GoalType.EMERGENCY_FUND:
        if progress < 100:
            insights['suggestion'] = 'Priorize essa reserva - ela te protege de imprevistos! ' + insights['suggestion']
    elif goal.goal_type == Goal.GoalType.INCOME_INCREASE:
        if progress < 50:
            insights['suggestion'] = 'Considere formas de aumentar sua renda extra. ' + insights['suggestion']
    
    return insights
