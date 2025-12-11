"""
Validador para missões de aumento de poupança.

Este validador conta transações em categorias de poupança/investimento 
e valida quando o usuário atinge o valor alvo de aportes.
"""

from decimal import Decimal
from typing import Any, Dict, Tuple

from django.db.models import Sum
from django.utils import timezone

from .base import BaseMissionValidator


class SavingsIncreaseValidator(BaseMissionValidator):
    """
    Valida missões que exigem aumento de poupança.
    
    Calcula o total de transações em categorias SAVINGS/INVESTMENT
    desde o início da missão e compara com o alvo definido.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        from ..models import Transaction, Category
        
        # Valor alvo de aportes
        target_amount = Decimal(str(self.mission.savings_increase_amount or 500))
        
        # Data de início da missão (ou 30 dias atrás se não iniciada)
        start_date = self.mission_progress.started_at
        if not start_date:
            start_date = timezone.now() - timezone.timedelta(days=30)
        else:
            # Converte para date se for datetime
            if hasattr(start_date, 'date'):
                start_date = start_date.date()
        
        # Busca aportes em poupança/investimento desde o início
        current_savings = Transaction.objects.filter(
            user=self.user,
            type=Transaction.TransactionType.EXPENSE,
            category__group__in=[
                Category.CategoryGroup.SAVINGS,
                Category.CategoryGroup.INVESTMENT
            ],
            date__gte=start_date
        ).aggregate(total=Sum('amount'))['total'] or Decimal('0')
        
        # Valor inicial (salvo na inicialização da missão)
        initial_savings = self.mission_progress.initial_savings_amount or Decimal('0')
        
        # Calcula progresso (quanto foi adicionado desde o início)
        added_amount = current_savings - initial_savings
        
        if target_amount <= 0:
            progress = 100 if added_amount > 0 else 0
        else:
            progress = min(100, max(0, float(added_amount / target_amount) * 100))
        
        is_completed = added_amount >= target_amount
        
        return {
            'progress_percentage': progress,
            'is_completed': is_completed,
            'metrics': {
                'initial_savings': float(initial_savings),
                'current_savings': float(current_savings),
                'added_amount': float(added_amount),
                'target_amount': float(target_amount),
                'remaining': float(max(0, target_amount - added_amount)),
            },
            'message': f"Você poupou R$ {added_amount:.2f} (meta: R$ {target_amount:.2f})"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        
        if result['is_completed']:
            added = result['metrics']['added_amount']
            target = result['metrics']['target_amount']
            return True, f"Parabéns! Você poupou R$ {added:.2f}, atingindo a meta de R$ {target:.2f}!"
        
        remaining = result['metrics']['remaining']
        return False, f"Continue poupando! Faltam R$ {remaining:.2f} para atingir a meta."
