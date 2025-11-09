"""
Tasks Celery para sistema de snapshots e validação de missões.

Este módulo contém todas as tasks automatizadas que rodam em background:
- Snapshots diários de usuários (23:59)
- Snapshots diários de missões ativas (23:59)
- Snapshots mensais consolidados (último dia do mês 23:59)
"""

import logging
from datetime import timedelta
from decimal import Decimal

from celery import shared_task
from django.contrib.auth import get_user_model
from django.db.models import Avg, Count, Min, Max, Sum, Q
from django.utils import timezone

from .models import (
    Category,
    Goal,
    Mission,
    MissionProgress,
    MissionProgressSnapshot,
    Transaction,
    UserDailySnapshot,
    UserMonthlySnapshot,
)
from .services import calculate_summary, apply_mission_reward

User = get_user_model()
logger = logging.getLogger(__name__)


# ============================================================================
# TASK 1: SNAPSHOTS DIÁRIOS DE USUÁRIOS
# ============================================================================

@shared_task(name='finance.create_daily_user_snapshots')
def create_daily_user_snapshots():
    """
    Task executada TODO DIA às 23:59 para criar snapshots de TODOS os usuários.
    
    Configurar no Celery Beat:
    CELERY_BEAT_SCHEDULE = {
        'create-daily-snapshots': {
            'task': 'finance.create_daily_user_snapshots',
            'schedule': crontab(hour=23, minute=59),
        },
    }
    
    Returns:
        int: Número de snapshots criados
    """
    today = timezone.now().date()
    users = User.objects.filter(is_active=True)
    
    created_count = 0
    
    for user in users:
        try:
            # Verificar se já existe snapshot de hoje
            if UserDailySnapshot.objects.filter(user=user, snapshot_date=today).exists():
                logger.info(f"Snapshot já existe para {user.username} em {today}")
                continue
            
            # Calcular indicadores atuais
            summary = calculate_summary(user)
            
            # Calcular gastos por categoria (mês atual)
            month_start = today.replace(day=1)
            category_spending = _calculate_category_spending(user, month_start, today)
            
            # Calcular progresso de metas
            goals_progress = _calculate_goals_progress(user)
            
            # Verificar se registrou transação hoje
            registered_today = Transaction.objects.filter(
                user=user,
                date=today
            ).exists()
            
            transaction_count_today = Transaction.objects.filter(
                user=user,
                date=today
            ).count()
            
            # Total de transações lifetime
            total_transactions = Transaction.objects.filter(user=user).count()
            
            # Verificar violações de orçamento
            budget_exceeded, violations = _check_budget_violations(user, today)
            
            # Poupança (transações de INCOME em categorias de investimento)
            savings_today = _calculate_savings_added_today(user, today)
            savings_total = _calculate_total_savings(user)
            
            # Criar snapshot
            snapshot = UserDailySnapshot.objects.create(
                user=user,
                snapshot_date=today,
                tps=summary.get('tps', Decimal('0')),
                rdr=summary.get('rdr', Decimal('0')),
                ili=summary.get('ili', Decimal('0')),
                total_income=summary.get('total_income', Decimal('0')),
                total_expense=summary.get('total_expense', Decimal('0')),
                total_debt=summary.get('total_debt', Decimal('0')),
                available_balance=summary.get('available_balance', Decimal('0')),
                category_spending=category_spending,
                savings_added_today=savings_today,
                savings_total=savings_total,
                goals_progress=goals_progress,
                transactions_registered_today=registered_today,
                transaction_count_today=transaction_count_today,
                total_transactions_lifetime=total_transactions,
                budget_exceeded=budget_exceeded,
                budget_violations=violations,
            )
            
            created_count += 1
            logger.info(f"✓ Snapshot criado para {user.username}")
            
        except Exception as e:
            logger.error(f"Erro ao criar snapshot para {user.username}: {e}", exc_info=True)
            continue
    
    logger.info(f"✓ {created_count} snapshots diários criados")
    return created_count


def _calculate_category_spending(user, start_date, end_date):
    """Calcula gastos por categoria no período."""
    spending = Transaction.objects.filter(
        user=user,
        type='EXPENSE',
        date__gte=start_date,
        date__lte=end_date,
        category__isnull=False,
    ).values('category__name').annotate(
        total=Sum('amount'),
        count=Count('id')
    )
    
    return {
        item['category__name']: {
            'total': float(item['total']),
            'count': item['count']
        }
        for item in spending if item['category__name']
    }


def _calculate_goals_progress(user):
    """Calcula progresso de todas as metas ativas."""
    goals = Goal.objects.filter(user=user, is_active=True)
    
    return {
        str(goal.id): {
            'name': goal.name,
            'progress': float(goal.progress),
            'current': float(goal.current_amount),
            'target': float(goal.target_amount),
        }
        for goal in goals
    }


def _check_budget_violations(user, date):
    """
    Verifica se excedeu orçamento em alguma categoria.
    
    TODO: Implementar lógica de orçamento quando modelo Budget existir.
    Por enquanto, retorna False.
    """
    return False, []


def _calculate_savings_added_today(user, date):
    """Calcula quanto foi adicionado em poupança hoje."""
    # Considera categorias de tipo INCOME com grupo de poupança/investimento
    savings = Transaction.objects.filter(
        user=user,
        date=date,
        type='INCOME',
        category__group__in=['SAVINGS', 'INVESTMENT']
    ).aggregate(total=Sum('amount'))
    
    return savings.get('total') or Decimal('0')


def _calculate_total_savings(user):
    """Calcula total acumulado em poupança."""
    savings = Transaction.objects.filter(
        user=user,
        type='INCOME',
        category__group__in=['SAVINGS', 'INVESTMENT']
    ).aggregate(total=Sum('amount'))
    
    return savings.get('total') or Decimal('0')


# ============================================================================
# TASK 2: SNAPSHOTS DIÁRIOS DE MISSÕES
# ============================================================================

@shared_task(name='finance.create_daily_mission_snapshots')
def create_daily_mission_snapshots():
    """
    Task executada TODO DIA às 23:59 para criar snapshots de MISSÕES ATIVAS.
    
    Executado DEPOIS de create_daily_user_snapshots para usar dados atualizados.
    
    Returns:
        int: Número de snapshots de missões criados
    """
    today = timezone.now().date()
    
    active_missions = MissionProgress.objects.filter(
        status__in=['PENDING', 'ACTIVE']
    ).select_related('mission', 'user')
    
    created_count = 0
    
    for progress in active_missions:
        try:
            # Verificar se já existe snapshot
            if MissionProgressSnapshot.objects.filter(
                mission_progress=progress,
                snapshot_date=today
            ).exists():
                logger.info(f"Snapshot já existe para missão {progress.id} em {today}")
                continue
            
            # Buscar snapshot do usuário (já foi criado)
            user_snapshot = UserDailySnapshot.objects.filter(
                user=progress.user,
                snapshot_date=today
            ).first()
            
            if not user_snapshot:
                logger.warning(f"Snapshot do usuário não encontrado para {progress.user}")
                continue
            
            # Calcular se atendeu critérios
            met_criteria, criteria_details = _evaluate_mission_criteria(
                progress,
                user_snapshot
            )
            
            # Calcular streak
            consecutive_days = _calculate_consecutive_days(progress, met_criteria)
            
            # Calcular progresso %
            progress_pct = _calculate_mission_progress_percentage(
                progress,
                user_snapshot,
                consecutive_days
            )
            
            # Criar snapshot da missão
            snapshot = MissionProgressSnapshot.objects.create(
                mission_progress=progress,
                snapshot_date=today,
                tps_value=user_snapshot.tps,
                rdr_value=user_snapshot.rdr,
                ili_value=user_snapshot.ili,
                category_spending=_get_category_spending_for_mission(progress, user_snapshot),
                goal_progress=_get_goal_progress_for_mission(progress, user_snapshot),
                savings_amount=user_snapshot.savings_total,
                met_criteria=met_criteria,
                criteria_details=criteria_details,
                consecutive_days_met=consecutive_days,
                progress_percentage=progress_pct,
            )
            
            # Atualizar MissionProgress
            _update_mission_progress_from_snapshot(progress, snapshot)
            
            created_count += 1
            logger.info(f"✓ Snapshot criado para missão {progress.mission.title}")
            
        except Exception as e:
            logger.error(f"Erro ao criar snapshot de missão {progress.id}: {e}", exc_info=True)
            continue
    
    logger.info(f"✓ {created_count} snapshots de missões criados")
    return created_count


def _evaluate_mission_criteria(progress, user_snapshot):
    """
    Avalia se missão atendeu critérios neste dia.
    
    Returns:
        tuple: (met_criteria: bool, criteria_details: dict)
    """
    mission = progress.mission
    details = {}
    met = True
    
    # Validar baseado no tipo
    if mission.validation_type == 'TEMPORAL':
        # Ex: Manter TPS > 20%
        if mission.target_tps is not None:
            actual_tps = float(user_snapshot.tps)
            required_tps = float(mission.target_tps)
            met_tps = actual_tps >= required_tps
            details['tps'] = {
                'required': required_tps,
                'actual': actual_tps,
                'met': met_tps
            }
            met = met and met_tps
        
        if mission.target_rdr is not None:
            actual_rdr = float(user_snapshot.rdr)
            required_rdr = float(mission.target_rdr)
            met_rdr = actual_rdr <= required_rdr  # Menor é melhor
            details['rdr'] = {
                'required': required_rdr,
                'actual': actual_rdr,
                'met': met_rdr
            }
            met = met and met_rdr
    
    elif mission.validation_type == 'SNAPSHOT':
        # Validação pontual (lógica antiga)
        if mission.target_tps is not None:
            actual_tps = float(user_snapshot.tps)
            required_tps = float(mission.target_tps)
            met_tps = actual_tps >= required_tps
            details['tps'] = {
                'required': required_tps,
                'actual': actual_tps,
                'met': met_tps
            }
            met = met and met_tps
    
    elif mission.validation_type == 'CATEGORY_LIMIT':
        # Ex: Não gastar mais que R$ 500 em Lazer
        if mission.target_category and mission.category_spending_limit:
            category_name = mission.target_category.name
            actual_spending = user_snapshot.category_spending.get(
                category_name, {}
            ).get('total', 0)
            limit = float(mission.category_spending_limit)
            met_limit = actual_spending <= limit
            details['category_limit'] = {
                'category': category_name,
                'limit': limit,
                'actual': actual_spending,
                'met': met_limit
            }
            met = met_limit
    
    elif mission.validation_type == 'CONSISTENCY':
        # Ex: Registrar transação todo dia
        if mission.requires_daily_action:
            registered = user_snapshot.transactions_registered_today
            details['daily_action'] = {
                'required': True,
                'actual': registered,
                'met': registered
            }
            met = registered
    
    # Adicionar mais tipos conforme necessário
    
    return met, details


def _calculate_consecutive_days(progress, met_today):
    """Calcula quantos dias consecutivos atendeu critério."""
    if not met_today:
        # Quebrou a sequência
        return 0
    
    # Buscar último snapshot
    last_snapshot = MissionProgressSnapshot.objects.filter(
        mission_progress=progress
    ).order_by('-snapshot_date').first()
    
    if not last_snapshot:
        return 1 if met_today else 0
    
    # Se último também atendeu, incrementa
    if last_snapshot.met_criteria:
        return last_snapshot.consecutive_days_met + 1
    else:
        return 1 if met_today else 0


def _calculate_mission_progress_percentage(progress, user_snapshot, consecutive_days):
    """Calcula % de progresso da missão."""
    mission = progress.mission
    
    if mission.validation_type == 'TEMPORAL':
        # Progresso = (dias consecutivos / dias requeridos) * 100
        if mission.requires_consecutive_days and mission.min_consecutive_days:
            return min(100, (consecutive_days / mission.min_consecutive_days) * 100)
        else:
            # Usar duration_days como alvo
            return min(100, (consecutive_days / mission.duration_days) * 100)
    
    elif mission.validation_type == 'CATEGORY_REDUCTION':
        # Progresso = (redução alcançada / redução alvo) * 100
        if progress.baseline_category_spending:
            category_name = mission.target_category.name
            current_spending = user_snapshot.category_spending.get(
                category_name, {}
            ).get('total', 0)
            baseline = float(progress.baseline_category_spending)
            
            if baseline > 0:
                reduction_pct = ((baseline - current_spending) / baseline) * 100
                target_pct = float(mission.target_reduction_percent or 0)
                
                if target_pct > 0:
                    return min(100, (reduction_pct / target_pct) * 100)
        return 0
    
    elif mission.validation_type == 'GOAL_PROGRESS':
        # Progresso baseado em meta
        if mission.target_goal:
            goal_id = str(mission.target_goal.id)
            goal_data = user_snapshot.goals_progress.get(goal_id)
            
            if goal_data:
                current_progress = goal_data['progress']
                target_progress = float(mission.goal_progress_target or 100)
                initial_progress = float(progress.initial_goal_progress or 0)
                
                if target_progress > initial_progress:
                    needed = target_progress - initial_progress
                    achieved = current_progress - initial_progress
                    return min(100, (achieved / needed) * 100)
        return 0
    
    elif mission.validation_type == 'SAVINGS_INCREASE':
        # Progresso baseado em aumento de poupança
        if mission.savings_increase_amount:
            initial = float(progress.initial_savings_amount or 0)
            current = float(user_snapshot.savings_total)
            target_increase = float(mission.savings_increase_amount)
            
            actual_increase = current - initial
            return min(100, (actual_increase / target_increase) * 100)
        return 0
    
    elif mission.validation_type == 'CONSISTENCY':
        # Progresso = dias atendidos / dias necessários
        if mission.duration_days:
            return min(100, (consecutive_days / mission.duration_days) * 100)
        return 0
    
    # Default: usar lógica antiga de snapshot
    return float(progress.progress)


def _get_category_spending_for_mission(progress, user_snapshot):
    """Retorna gasto da categoria alvo (se aplicável)."""
    mission = progress.mission
    
    if mission.target_category:
        category_name = mission.target_category.name
        return Decimal(str(user_snapshot.category_spending.get(
            category_name, {}
        ).get('total', 0)))
    
    return None


def _get_goal_progress_for_mission(progress, user_snapshot):
    """Retorna progresso da meta alvo (se aplicável)."""
    mission = progress.mission
    
    if mission.target_goal:
        goal_id = str(mission.target_goal.id)
        goal_data = user_snapshot.goals_progress.get(goal_id)
        
        if goal_data:
            return Decimal(str(goal_data['progress']))
    
    return None


def _update_mission_progress_from_snapshot(progress, snapshot):
    """Atualiza MissionProgress baseado no snapshot criado."""
    progress.progress = snapshot.progress_percentage
    progress.current_streak = snapshot.consecutive_days_met
    progress.max_streak = max(progress.max_streak, snapshot.consecutive_days_met)
    
    if snapshot.met_criteria:
        progress.days_met_criteria += 1
    else:
        progress.days_violated_criteria += 1
        progress.last_violation_date = snapshot.snapshot_date
        progress.current_streak = 0  # Resetar streak
    
    # Completar se atingiu 100%
    if snapshot.progress_percentage >= 100:
        progress.status = 'COMPLETED'
        progress.completed_at = timezone.now()
        apply_mission_reward(progress)
    
    # Ativar se estava pendente e tem progresso
    elif progress.status == 'PENDING' and snapshot.progress_percentage > 0:
        progress.status = 'ACTIVE'
        progress.started_at = timezone.now()
    
    # Verificar expiração
    if progress.started_at and progress.mission.duration_days:
        deadline = progress.started_at.date() + timedelta(days=progress.mission.duration_days)
        if timezone.now().date() > deadline and progress.status != 'COMPLETED':
            progress.status = 'FAILED'
    
    progress.save()
    logger.info(f"✓ Missão {progress.mission.title} atualizada: {snapshot.progress_percentage}%")


# ============================================================================
# TASK 3: SNAPSHOTS MENSAIS CONSOLIDADOS
# ============================================================================

@shared_task(name='finance.create_monthly_snapshots')
def create_monthly_snapshots():
    """
    Task executada no ÚLTIMO DIA DO MÊS para consolidar snapshots mensais.
    
    Configurar no Celery Beat:
    CELERY_BEAT_SCHEDULE = {
        'create-monthly-snapshots': {
            'task': 'finance.create_monthly_snapshots',
            'schedule': crontab(day_of_month='last', hour=23, minute=59),
        },
    }
    
    Returns:
        int: Número de snapshots mensais criados
    """
    today = timezone.now().date()
    year = today.year
    month = today.month
    
    users = User.objects.filter(is_active=True)
    created_count = 0
    
    for user in users:
        try:
            # Verificar se já existe snapshot mensal
            if UserMonthlySnapshot.objects.filter(user=user, year=year, month=month).exists():
                logger.info(f"Snapshot mensal já existe para {user.username} em {year}/{month}")
                continue
            
            # Buscar snapshots diários do mês
            daily_snapshots = UserDailySnapshot.objects.filter(
                user=user,
                snapshot_date__year=year,
                snapshot_date__month=month
            )
            
            if not daily_snapshots.exists():
                logger.warning(f"Nenhum snapshot diário encontrado para {user.username} em {year}/{month}")
                continue
            
            # Calcular médias
            averages = daily_snapshots.aggregate(
                avg_tps=Avg('tps'),
                avg_rdr=Avg('rdr'),
                avg_ili=Avg('ili')
            )
            
            # Último snapshot do mês
            last_snapshot = daily_snapshots.order_by('-snapshot_date').first()
            
            # Consolidar gastos por categoria
            category_spending = {}
            for snapshot in daily_snapshots:
                for cat, data in snapshot.category_spending.items():
                    if cat not in category_spending:
                        category_spending[cat] = {'total': 0, 'count': 0}
                    category_spending[cat]['total'] += data['total']
                    category_spending[cat]['count'] += data['count']
            
            # Categoria top
            top_cat = max(
                category_spending.items(),
                key=lambda x: x[1]['total']
            ) if category_spending else (None, {'total': 0})
            
            # Dias com transações
            days_with_trans = daily_snapshots.filter(
                transactions_registered_today=True
            ).count()
            
            total_days = daily_snapshots.count()
            consistency = (days_with_trans / total_days * 100) if total_days > 0 else 0
            
            # Criar snapshot mensal
            UserMonthlySnapshot.objects.create(
                user=user,
                year=year,
                month=month,
                avg_tps=averages['avg_tps'] or 0,
                avg_rdr=averages['avg_rdr'] or 0,
                avg_ili=averages['avg_ili'] or 0,
                total_income=last_snapshot.total_income,
                total_expense=last_snapshot.total_expense,
                total_savings=last_snapshot.savings_total,
                top_category=top_cat[0] or '',
                top_category_amount=Decimal(str(top_cat[1]['total'])),
                category_spending=category_spending,
                days_with_transactions=days_with_trans,
                days_in_month=total_days,
                consistency_rate=Decimal(str(consistency)),
            )
            
            created_count += 1
            logger.info(f"✓ Snapshot mensal criado para {user.username}")
            
        except Exception as e:
            logger.error(f"Erro ao criar snapshot mensal para {user.username}: {e}", exc_info=True)
            continue
    
    logger.info(f"✓ {created_count} snapshots mensais criados")
    return created_count
