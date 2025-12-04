from __future__ import annotations

from datetime import timedelta
from decimal import Decimal
from typing import Any, Dict, List, Tuple

from django.db.models import Q
from django.utils import timezone

from ..models import Mission, MissionProgress, Transaction, UserProfile
from .base import _decimal, _xp_threshold, logger
from .context import analyze_user_context, identify_improvement_opportunities
from .indicators import calculate_summary


def assign_missions_smartly(user, max_active: int = 3) -> List[MissionProgress]:
    """Atribui missões inteligentemente baseado em análise contextual (até max_active missões)."""
    existing_progress = MissionProgress.objects.filter(user=user)
    active_missions = existing_progress.filter(
        status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
    )
    
    active_count = active_missions.count()
    
    if active_count >= max_active:
        return list(active_missions)
    
    slots_available = max_active - active_count
    context = analyze_user_context(user)
    mission_priorities = calculate_mission_priorities(user, context)
    
    already_assigned_ids = set(existing_progress.values_list('mission_id', flat=True))
    available_with_priority = [
        (mission, score) for mission, score in mission_priorities 
        if mission.id not in already_assigned_ids and score > 0
    ]
    
    selected_missions = []
    selected_types = set(active_missions.values_list('mission__mission_type', flat=True))
    
    for mission, score in available_with_priority:
        if len(selected_missions) >= slots_available:
            break
        
        if mission.mission_type in selected_types:
            if score < 70:
                continue
        
        selected_missions.append(mission)
        selected_types.add(mission.mission_type)
    
    new_progress_list = []
    for mission in selected_missions:
        should_auto_start = mission.mission_type in [
            'ONBOARDING_TRANSACTIONS',
            'ONBOARDING_CATEGORIES', 
            'ONBOARDING_GOALS'
        ]
        
        progress, created = MissionProgress.objects.get_or_create(
            user=user,
            mission=mission,
            defaults={
                'status': MissionProgress.Status.ACTIVE if should_auto_start else MissionProgress.Status.PENDING,
                'started_at': timezone.now() if should_auto_start else None,
            }
        )
        
        if not created and should_auto_start and progress.status == MissionProgress.Status.PENDING:
            progress.status = MissionProgress.Status.ACTIVE
            progress.started_at = timezone.now()
            progress.save()
        
        new_progress_list.append(progress)
    
    all_active = list(active_missions) + new_progress_list
    return all_active


def calculate_mission_priorities(user, context: Dict[str, Any] = None) -> List[Tuple[Mission, float]]:
    """Calcula score de prioridade de missões baseado em contexto e oportunidades."""
    if context is None:
        context = analyze_user_context(user)
    
    opportunities = identify_improvement_opportunities(user)
    at_risk = context.get('at_risk_indicators', [])
    
    already_assigned = MissionProgress.objects.filter(user=user).values_list('mission_id', flat=True)
    available_missions = Mission.objects.filter(
        is_active=True
    ).exclude(id__in=already_assigned)
    
    mission_scores = []
    
    for mission in available_missions:
        score = 0.0
        
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
        
        for opp in opportunities:
            if opp['type'] == 'CATEGORY_GROWTH' and mission.mission_type in ['CATEGORY_REDUCTION', 'CATEGORY_SPENDING_LIMIT']:
                if mission.target_category and mission.target_category.id == opp['data'].get('category_id'):
                    score += 30
                else:
                    score += 15
            elif opp['type'] == 'GOAL_STAGNANT' and mission.mission_type in ['GOAL_ACHIEVEMENT', 'GOAL_CONSISTENCY']:
                if mission.target_goal and mission.target_goal.id == opp['data'].get('goal_id'):
                    score += 30
                else:
                    score += 15
        
        difficulty_multiplier = {
            'EASY': 1.0,
            'MEDIUM': 0.7,
            'HARD': 0.4
        }
        reward_points = mission.reward_points or 50
        difficulty_factor = difficulty_multiplier.get(mission.difficulty, 0.7)
        score += (reward_points / 100) * difficulty_factor * 20
        
        priority_score = max(0, 11 - mission.priority)
        score += priority_score
        
        transaction_count = context.get('transaction_count', 0)
        if mission.min_transactions and transaction_count < mission.min_transactions:
            score *= 0.1
        
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
    
    mission_scores.sort(key=lambda x: x[1], reverse=True)
    
    return mission_scores


def apply_mission_reward(progress: MissionProgress) -> None:
    """
    Aplica recompensa de XP ao completar uma missão.
    Usa transaction.atomic e select_for_update para evitar race conditions.
    """
    from django.db import transaction
    from ..models import XPTransaction
    
    with transaction.atomic():
        profile = UserProfile.objects.select_for_update().get(user=progress.user)
        
        level_before = profile.level
        xp_before = profile.experience_points
        
        profile.experience_points += progress.mission.reward_points

        while profile.experience_points >= _xp_threshold(profile.level):
            profile.experience_points -= _xp_threshold(profile.level)
            profile.level += 1
        
        profile.save(update_fields=["experience_points", "level"])
        
        XPTransaction.objects.create(
            user=progress.user,
            mission_progress=progress,
            points_awarded=progress.mission.reward_points,
            level_before=level_before,
            level_after=profile.level,
            xp_before=xp_before,
            xp_after=profile.experience_points,
        )


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
    """
    summary = calculate_summary(user)
    tps = float(summary.get("tps", Decimal("0")))
    rdr = float(summary.get("rdr", Decimal("0")))
    ili = float(summary.get("ili", Decimal("0")))
    
    transaction_count = Transaction.objects.filter(user=user).count()
    
    existing_progress = MissionProgress.objects.filter(user=user)
    active_count = existing_progress.filter(
        status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
    ).count()
    
    if active_count >= 3:
        return list(existing_progress.filter(
            status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
        ))
    
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
    
    already_linked = set(
        existing_progress.values_list("mission_id", flat=True)
    )
    
    available_missions = Mission.objects.filter(
        is_active=True,
        mission_type__in=priority_types,
    ).exclude(id__in=already_linked).order_by('priority')
    
    suitable_missions = []
    for mission in available_missions:
        if mission.min_transactions and transaction_count < mission.min_transactions:
            continue
        
        if mission.target_tps is not None:
            if tps >= mission.target_tps:
                continue
        
        if mission.target_rdr is not None:
            if rdr <= mission.target_rdr:
                continue
        
        if mission.min_ili is not None:
            if ili >= float(mission.min_ili):
                continue
        
        if mission.max_ili is not None:
            if ili > float(mission.max_ili):
                continue
        
        if mission.mission_type not in ['ONBOARDING_TRANSACTIONS', 'ONBOARDING_CATEGORIES', 'ONBOARDING_GOALS']:
            would_complete_instantly = False
            
            if mission.target_tps is not None and tps >= mission.target_tps * 0.95:
                would_complete_instantly = True
            
            if mission.target_rdr is not None and rdr <= mission.target_rdr * 1.05:
                would_complete_instantly = True
            
            if mission.min_ili is not None and ili >= float(mission.min_ili) * 0.95:
                would_complete_instantly = True
            
            if would_complete_instantly:
                continue
        
        suitable_missions.append(mission)
        
        if len(suitable_missions) >= (3 - active_count):
            break
    
    if not suitable_missions and active_count == 0:
        suitable_missions = list(available_missions[:3])
    
    if not suitable_missions and active_count == 0:
        suitable_missions = list(
            Mission.objects.filter(is_active=True)
            .exclude(id__in=already_linked)
            .order_by('priority')[:3]
        )
    
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
            initialize_mission_progress(progress)
            created_progress.append(progress)
    
    return created_progress


def update_mission_progress(user) -> List[MissionProgress]:
    """
    Atualiza o progresso das missões ativas do usuário baseado em seus dados atuais.
    Usa validadores especializados por tipo de missão (mission_types.py).
    """
    from django.db import transaction
    from ..mission_types import MissionValidatorFactory
    
    with transaction.atomic():
        active_missions = MissionProgress.objects.select_for_update().filter(
            user=user,
            status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
        )
        
        if not active_missions:
            return []
        
        missions_to_update = list(active_missions)
    
    updated = []
    
    for progress in missions_to_update:
        try:
            validator = MissionValidatorFactory.create_validator(
                progress.mission,
                user,
                progress
            )
            
            result = validator.calculate_progress()
            
            old_progress = float(progress.progress)
            new_progress = result['progress_percentage']
            
            progress.progress = Decimal(str(new_progress))
            
            if result['is_completed'] and not progress.completed_at:
                is_valid, message = validator.validate_completion()
                
                if is_valid:
                    progress.completed_at = timezone.now()
                    progress.status = MissionProgress.Status.COMPLETED
                    progress.status = MissionProgress.Status.COMPLETED
                    progress.save()
                    
                    apply_mission_reward(progress)
                    
                    logger.info(f"Missão completada: {progress.mission.title} - {message}")
                else:
                    progress.save()
            else:
                progress.save()
            
            if abs(new_progress - old_progress) > 0.1:
                updated.append(progress)
                logger.debug(f"Progresso atualizado para {progress.mission.title}: {old_progress:.1f}% → {new_progress:.1f}%")
                
        except Exception as e:
            import traceback
            logger.error(f"Erro ao atualizar progresso da missão {progress.mission.title}: {e}")
            logger.error(f"Traceback: {traceback.format_exc()}")
            continue
    
    return updated


def initialize_mission_progress(progress):
    """
    Inicializa MissionProgress com todos os baselines necessários.
    Chamado quando missão é atribuída ao usuário pela primeira vez.
    """
    from django.db.models import Sum
    
    user = progress.user
    mission = progress.mission
    
    summary = calculate_summary(user)
    
    progress.initial_tps = summary.get('tps', Decimal('0'))
    progress.initial_rdr = summary.get('rdr', Decimal('0'))
    progress.initial_ili = summary.get('ili', Decimal('0'))
    progress.initial_transaction_count = Transaction.objects.filter(user=user).count()
    
    if mission.validation_type in ['CATEGORY_REDUCTION', 'CATEGORY_LIMIT']:
        if mission.target_category:
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
    
    if mission.validation_type == 'GOAL_PROGRESS':
        if mission.target_goal:
            goal = mission.target_goal
            progress.initial_goal_progress = goal.progress
    
    if mission.validation_type == 'SAVINGS_INCREASE':
        savings = Transaction.objects.filter(
            user=user,
            type='INCOME',
            category__group__in=['SAVINGS', 'INVESTMENT']
        ).aggregate(total=Sum('amount'))
        
        progress.initial_savings_amount = savings.get('total') or Decimal('0')
    
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
    Útil para validação imediata após transação ou verificação on-demand.
    """
    from ..models import UserDailySnapshot
    
    today = timezone.now().date()
    snapshot = UserDailySnapshot.objects.filter(
        user=progress.user,
        snapshot_date=today
    ).first()
    
    if not snapshot:
        summary = calculate_summary(progress.user)
        
        from ..tasks import (
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
    
    from ..tasks import (
        _evaluate_mission_criteria,
        _calculate_consecutive_days,
        _calculate_mission_progress_percentage
    )
    
    met_criteria, details = _evaluate_mission_criteria(progress, snapshot)
    
    consecutive = _calculate_consecutive_days(progress, met_criteria)
    progress_pct = _calculate_mission_progress_percentage(progress, snapshot, consecutive)
    
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
