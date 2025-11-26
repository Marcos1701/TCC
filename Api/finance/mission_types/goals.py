"""
Validadores para missões relacionadas a metas financeiras.
"""

from decimal import Decimal
from typing import Any, Dict, Tuple

from django.db.models import Sum

from .base import BaseMissionValidator


class GoalProgressValidator(BaseMissionValidator):
    """
    Validador para missões de progresso em metas.
    
    Foco: Atingir X% de progresso em uma meta específica.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        if not self.mission.target_goal_id:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão sem meta alvo configurada'
            }
        
        goal = self.mission.target_goal
        current_amount = goal.current_amount or Decimal('0')
        target_amount = goal.target_amount
        
        goal_progress = (current_amount / target_amount * 100) if target_amount > 0 else Decimal('0')
        target_progress = self.mission.goal_progress_target or Decimal('100')
        
        mission_progress = min(Decimal('100'), (goal_progress / target_progress) * 100)
        
        return {
            'progress_percentage': float(mission_progress),
            'is_completed': goal_progress >= target_progress,
            'metrics': {
                'goal_name': goal.title,
                'current_amount': float(current_amount),
                'target_amount': float(target_amount),
                'goal_progress': float(goal_progress),
                'target_progress': float(target_progress)
            },
            'message': f"Meta '{goal.title}' em {goal_progress:.1f}%"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, f"Parabéns! Você atingiu o progresso necessário em {result['metrics']['goal_name']}!"
        return False, f"Continue contribuindo para {result['metrics']['goal_name']}"


class GoalContributionValidator(BaseMissionValidator):
    """
    Validador para missões de contribuição para metas.
    
    Foco: Contribuir R$ X para uma meta durante o período.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        from ..models import Transaction
        
        if not self.mission.target_goal_id:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão sem meta alvo configurada'
            }
        
        if not self.mission_progress.started_at:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão ainda não foi iniciada'
            }
        
        contributions = Transaction.objects.filter(
            user=self.user,
            goal=self.mission.target_goal,
            date__gte=self.mission_progress.started_at.date()
        ).aggregate(total=Sum('amount'))['total'] or Decimal('0')
        
        target_contribution = self.mission.savings_increase_amount or Decimal('100')
        progress = min(100, (contributions / target_contribution) * 100)
        
        return {
            'progress_percentage': float(progress),
            'is_completed': contributions >= target_contribution,
            'metrics': {
                'goal_name': self.mission.target_goal.title,
                'contributions': float(contributions),
                'target_contribution': float(target_contribution),
                'remaining': float(target_contribution - contributions)
            },
            'message': f"R$ {contributions:.2f} / R$ {target_contribution:.2f} contribuídos"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, f"Parabéns! Você contribuiu o valor necessário para {result['metrics']['goal_name']}!"
        return False, f"Continue contribuindo para {result['metrics']['goal_name']}"
