"""
Validadores para missões relacionadas a categorias de despesas.
"""

from datetime import timedelta
from decimal import Decimal
from typing import Any, Dict, Tuple

from django.db.models import Sum
from django.utils import timezone

from .base import BaseMissionValidator


class CategoryReductionValidator(BaseMissionValidator):
    """
    Validador para missões de redução de gastos em categorias específicas.
    
    Foco: Reduzir X% os gastos em uma categoria comparando período atual vs anterior.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        from ..models import Transaction
        
        if not self.mission.target_category:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão sem categoria alvo configurada'
            }
        
        if not self.mission_progress.started_at:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão ainda não foi iniciada'
            }
        
        mission_duration = self.mission.duration_days
        start_date = self.mission_progress.started_at
        
        reference_start = start_date - timedelta(days=mission_duration)
        reference_end = start_date
        current_start = start_date
        current_end = timezone.now()
        
        reference_query = Transaction.objects.filter(
            user=self.user,
            type='EXPENSE',
            date__gte=reference_start.date(),
            date__lt=reference_end.date()
        )
        if self.mission.target_category:
            reference_query = reference_query.filter(category=self.mission.target_category)
        reference_spending = reference_query.aggregate(total=Sum('amount'))['total'] or Decimal('0')
        
        current_query = Transaction.objects.filter(
            user=self.user,
            type='EXPENSE',
            date__gte=current_start.date(),
            date__lt=current_end.date()
        )
        if self.mission.target_category:
            current_query = current_query.filter(category=self.mission.target_category)
        current_spending = current_query.aggregate(total=Sum('amount'))['total'] or Decimal('0')
        
        if reference_spending > 0:
            reduction_percent = ((reference_spending - current_spending) / reference_spending) * 100
        else:
            reduction_percent = Decimal('0')
        
        target_reduction = self.mission.target_reduction_percent or Decimal('10')
        progress = min(100, (reduction_percent / target_reduction) * 100)
        
        return {
            'progress_percentage': float(progress),
            'is_completed': reduction_percent >= target_reduction,
            'metrics': {
                'reference_spending': float(reference_spending),
                'current_spending': float(current_spending),
                'reduction_percent': float(reduction_percent),
                'target_reduction': float(target_reduction),
                'category_name': self.mission.target_category.name
            },
            'message': f"Redução de {reduction_percent:.1f}% em {self.mission.target_category.name}"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, f"Parabéns! Você reduziu os gastos em {result['metrics']['category_name']}!"
        return False, f"Continue reduzindo gastos em {result['metrics']['category_name']}"


class CategoryLimitValidator(BaseMissionValidator):
    """
    Validador para missões de limite de gastos em categoria.
    
    Foco: Não exceder R$ X em uma categoria durante o período.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        from ..models import Transaction
        
        if not self.mission.target_category or not self.mission.category_spending_limit:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão sem categoria ou limite configurado'
            }
        
        if not self.mission_progress.started_at:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão ainda não foi iniciada'
            }
        
        spending_query = Transaction.objects.filter(
            user=self.user,
            type='EXPENSE',
            date__gte=self.mission_progress.started_at.date()
        )
        if self.mission.target_category:
            spending_query = spending_query.filter(category=self.mission.target_category)
        current_spending = spending_query.aggregate(total=Sum('amount'))['total'] or Decimal('0')
        
        limit = self.mission.category_spending_limit
        remaining = limit - current_spending
        
        if current_spending > limit:
            progress = 0
            is_completed = False
        else:
            elapsed_days = (timezone.now() - self.mission_progress.started_at).days
            mission_days = self.mission.duration_days
            time_progress = min(100, (elapsed_days / mission_days) * 100)
            progress = time_progress
            is_completed = elapsed_days >= mission_days
        
        return {
            'progress_percentage': float(progress),
            'is_completed': is_completed,
            'metrics': {
                'current_spending': float(current_spending),
                'limit': float(limit),
                'remaining': float(remaining),
                'exceeded': current_spending > limit,
                'category_name': self.mission.target_category.name
            },
            'message': f"R$ {remaining:.2f} restantes do limite em {self.mission.target_category.name}"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['metrics']['exceeded']:
            return False, f"Você excedeu o limite de {self.mission.target_category.name}"
        if result['is_completed']:
            return True, f"Parabéns! Você respeitou o limite em {self.mission.target_category.name}!"
        return False, "Continue respeitando o limite"
