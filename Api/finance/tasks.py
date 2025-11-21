"""
Tasks Celery para sistema de snapshots e validação de missões.
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


@shared_task(name='finance.create_daily_user_snapshots')
def create_daily_user_snapshots():
    """
    Task executada diariamente às 23:59 para criar snapshots de todos os usuários.
    """
    today = timezone.now().date()
    users = User.objects.filter(is_active=True)
    
    created_count = 0
    
    for user in users:
        try:
            if UserDailySnapshot.objects.filter(user=user, snapshot_date=today).exists():
                logger.info(f"Snapshot já existe para {user.username} em {today}")
                continue
            
            summary = calculate_summary(user)
            
            month_start = today.replace(day=1)
            category_spending = _calculate_category_spending(user, month_start, today)
            
            goals_progress = _calculate_goals_progress(user)
            
            registered_today = Transaction.objects.filter(
                user=user,
                date=today
            ).exists()
            
            transaction_count_today = Transaction.objects.filter(
                user=user,
                date=today
            ).count()
            
            total_transactions = Transaction.objects.filter(user=user).count()
            
            budget_exceeded, violations = _check_budget_exceeded(user, today)
            
            savings_today = _calculate_savings_added_today(user, today)
            savings_total = _calculate_total_savings(user)
            
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


def _check_budget_exceeded(user, date):
    """
    Verifica se excedeu orçamento em alguma categoria.
    Por enquanto, retorna False (funcionalidade de orçamento não implementada).
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


# ============================================================================
# TASK 4: GERAÇÃO ASSÍNCRONA DE MISSÕES COM IA
# ============================================================================

@shared_task(bind=True, name='finance.generate_missions_async')
def generate_missions_async(
    self,
    tier: str,
    scenario_key: str,
    count: int = 20,
    use_templates_first: bool = True
):
    """
    Task assíncrona para geração de missões com IA.
    
    Esta task roda em background worker Celery, permitindo processamento
    de até 10+ minutos sem timeout do servidor HTTP.
    
    Args:
        self: Task instance (bind=True)
        tier: Faixa do usuário (BEGINNER, INTERMEDIATE, ADVANCED, EXPERT)
        scenario_key: Cenário do usuário (low_activity, etc)
        count: Número de missões a gerar
        use_templates_first: Se deve priorizar templates
        
    Returns:
        dict: Resultado da geração com missões criadas/falhas
        
    Progress Tracking:
        A task atualiza o cache com progresso:
        - task_id: ID da task (self.request.id)
        - status: PENDING, STARTED, SUCCESS, FAILURE
        - current: Missão atual sendo gerada (1-20)
        - total: Total de missões (20)
        - percent: Porcentagem (0-100)
        - created: Lista de missões criadas
        - message: Mensagem de status
    """
    from django.core.cache import cache
    from finance.ai_services import generate_hybrid_missions
    
    task_id = self.request.id
    logger.info(f"[Task {task_id}] Iniciando geração assíncrona: {count} missões ({tier}/{scenario_key})")
    
    # Inicializar progresso no cache (TTL: 1 hora)
    cache_key = f'mission_generation_{task_id}'
    cache.set(cache_key, {
        'task_id': task_id,
        'status': 'STARTED',
        'current': 0,
        'total': count,
        'percent': 0,
        'created': [],
        'failed': [],
        'message': 'Inicializando geração...',
        'tier': tier,
        'scenario': scenario_key
    }, timeout=3600)
    
    try:
        # FASE 1: Templates
        cache.set(cache_key, {
            'task_id': task_id,
            'status': 'STARTED',
            'current': 0,
            'total': count,
            'percent': 5,
            'created': [],
            'failed': [],
            'message': '🎯 Gerando missões de templates...',
            'tier': tier,
            'scenario': scenario_key
        }, timeout=3600)
        
        # Callback de progresso
        def update_progress(current: int, total: int, message: str):
            percent = int((current / total) * 100) if total > 0 else 0
            cached_data = cache.get(cache_key) or {}
            cached_data.update({
                'current': current,
                'total': total,
                'percent': percent,
                'message': message
            })
            cache.set(cache_key, cached_data, timeout=3600)
            logger.debug(f"[Task {task_id}] Progresso: {current}/{total} ({percent}%) - {message}")
        
        # Chamar função principal
        result = generate_hybrid_missions(
            tier=tier,
            scenario_key=scenario_key,
            count=count,
            use_templates_first=use_templates_first
        )
        
        # Sucesso
        created_missions = result.get('created', [])
        failed_missions = result.get('failed', [])
        summary = result.get('summary', {})
        
        logger.info(f"[Task {task_id}] Geração concluída: {len(created_missions)} criadas, {len(failed_missions)} falhas")
        
        cache.set(cache_key, {
            'task_id': task_id,
            'status': 'SUCCESS',
            'current': count,
            'total': count,
            'percent': 100,
            'created': created_missions,
            'failed': failed_missions,
            'summary': summary,
            'message': f'✅ Concluído: {len(created_missions)} missões criadas',
            'tier': tier,
            'scenario': scenario_key
        }, timeout=3600)
        
        return result
        
    except Exception as e:
        logger.error(f"[Task {task_id}] Erro na geração: {str(e)}", exc_info=True)
        
        cache.set(cache_key, {
            'task_id': task_id,
            'status': 'FAILURE',
            'current': 0,
            'total': count,
            'percent': 0,
            'created': [],
            'failed': [],
            'error': str(e),
            'message': f'❌ Erro: {str(e)}',
            'tier': tier,
            'scenario': scenario_key
        }, timeout=3600)
        
        raise


@shared_task(name='finance.cleanup_old_missions')
def cleanup_old_missions(days: int = 90):
    """
    Remove missões inativas antigas (execução periódica via Celery Beat).
    
    Args:
        days: Remover missões inativas há mais de X dias
        
    Returns:
        dict: Número de missões removidas
    """
    from datetime import timedelta
    
    cutoff_date = timezone.now() - timedelta(days=days)
    
    old_missions = Mission.objects.filter(
        is_active=False,
        created_at__lt=cutoff_date
    )
    
    count = old_missions.count()
    old_missions.delete()
    
    logger.info(f"Limpeza: {count} missões inativas (>{days} dias) removidas")
    
    return {
        'removed': count,
        'cutoff_date': cutoff_date.isoformat(),
        'days': days
    }
