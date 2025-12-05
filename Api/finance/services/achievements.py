from __future__ import annotations

from decimal import Decimal
from typing import List

from django.db.models import F, Q, Sum

from ..models import (
    Category, MissionProgress, Transaction, UserProfile
)
from .base import _decimal, logger
from .indicators import calculate_summary


def check_achievements_for_user(user, event_type='generic'):
    """
    Valida e desbloqueia conquistas automaticamente para o usuário.
    
    Chamada de:
    - Signals: transaction_created, mission_completed, goal_completed
    - Celery tasks: daily_streak_check
    """
    try:
        from ..models import Achievement, UserAchievement
    except ImportError:
        logger.warning("Achievement models not available")
        return []
    
    unlocked_ids = UserAchievement.objects.filter(
        user=user, 
        is_unlocked=True
    ).values_list('achievement_id', flat=True)
    
    achievements = Achievement.objects.filter(
        is_active=True
    ).exclude(id__in=unlocked_ids)
    
    if event_type == 'transaction':
        achievements = achievements.filter(category='FINANCIAL')
    elif event_type == 'mission':
        achievements = achievements.filter(category='MISSION')
    elif event_type == 'streak':
        achievements = achievements.filter(category='STREAK')
    
    newly_unlocked = []
    
    for achievement in achievements:
        criteria = achievement.criteria
        
        if check_criteria_met(user, criteria):
            user_achievement, created = UserAchievement.objects.get_or_create(
                user=user,
                achievement=achievement,
                defaults={
                    'progress': criteria.get('target', 100),
                    'progress_max': criteria.get('target', 100),
                }
            )
            
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
    2. value: Valor numérico de indicadores (TPS, RDR, ILI, savings, etc.)
    3. streak: Dias consecutivos de atividade
    """
    if not criteria or not isinstance(criteria, dict):
        return False
    
    ctype = criteria.get('type')
    target = criteria.get('target', 0)
    metric = criteria.get('metric', '')
    duration = criteria.get('duration')
    
    if ctype == 'count':
        if metric == 'transactions':
            count = Transaction.objects.filter(user=user).count()
            return count >= target
        
        elif metric == 'income_transactions':
            count = Transaction.objects.filter(
                user=user, 
                type=Transaction.TransactionType.INCOME
            ).count()
            return count >= target
        
        elif metric == 'expense_transactions':
            count = Transaction.objects.filter(
                user=user, 
                type=Transaction.TransactionType.EXPENSE
            ).count()
            return count >= target
        
        elif metric == 'missions':
            count = MissionProgress.objects.filter(
                user=user, 
                status='COMPLETED'
            ).count()
            return count >= target
        
        elif metric == 'friends':
            from ..models import Friendship
            count = Friendship.objects.filter(
                Q(from_user=user, status=Friendship.FriendshipStatus.ACCEPTED) |
                Q(to_user=user, status=Friendship.FriendshipStatus.ACCEPTED)
            ).count()
            return count >= target
        
        elif metric == 'categories':
            count = Category.objects.filter(
                user=user,
                is_default=False
            ).count()
            return count >= target
    
    elif ctype == 'value':
        if metric == 'tps':
            summary = calculate_summary(user)
            tps = summary.get('tps', Decimal('0'))
            return tps >= target
        
        elif metric == 'ili':
            summary = calculate_summary(user)
            ili = summary.get('ili', Decimal('0'))
            return ili >= target
        
        elif metric == 'rdr':
            summary = calculate_summary(user)
            rdr = summary.get('rdr', Decimal('0'))
            return rdr <= target
        
        elif metric == 'total_income':
            total = Transaction.objects.filter(
                user=user,
                type=Transaction.TransactionType.INCOME
            ).aggregate(total=Sum('amount'))['total'] or Decimal('0')
            return total >= target
        
        elif metric == 'total_expense':
            total = Transaction.objects.filter(
                user=user,
                type=Transaction.TransactionType.EXPENSE
            ).aggregate(total=Sum('amount'))['total'] or Decimal('0')
            return total >= target
        
        elif metric == 'savings':
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
            profile, _ = UserProfile.objects.get_or_create(user=user)
            return profile.experience_points >= target
        
        elif metric == 'level':
            profile, _ = UserProfile.objects.get_or_create(user=user)
            return profile.level >= target
    
    elif ctype == 'streak':
        return False
    
    return False


def update_achievement_progress(user, achievement_id):
    """
    Atualiza o progresso de uma conquista específica para o usuário.
    Útil para mostrar progresso parcial antes do unlock completo.
    """
    try:
        from ..models import Achievement, UserAchievement
    except ImportError:
        logger.warning("Achievement models not available")
        return None
    
    try:
        achievement = Achievement.objects.get(id=achievement_id, is_active=True)
    except Achievement.DoesNotExist:
        return None
    
    user_achievement, created = UserAchievement.objects.get_or_create(
        user=user,
        achievement=achievement,
        defaults={
            'progress': 0,
            'progress_max': achievement.criteria.get('target', 100),
        }
    )
    
    if user_achievement.is_unlocked:
        return user_achievement
    
    criteria = achievement.criteria
    ctype = criteria.get('type')
    metric = criteria.get('metric')
    target = criteria.get('target', 100)
    
    current_progress = 0
    
    if ctype == 'count':
        if metric == 'transactions':
            current_progress = Transaction.objects.filter(user=user).count()
        elif metric == 'missions':
            current_progress = MissionProgress.objects.filter(user=user, status='COMPLETED').count()
        elif metric == 'friends':
            from ..models import Friendship
            current_progress = Friendship.objects.filter(
                Q(from_user=user, status=Friendship.FriendshipStatus.ACCEPTED) |
                Q(to_user=user, status=Friendship.FriendshipStatus.ACCEPTED)
            ).count()
    
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
    
    user_achievement.progress = min(current_progress, target)
    user_achievement.progress_max = target
    user_achievement.save(update_fields=['progress', 'progress_max'])
    
    return user_achievement
