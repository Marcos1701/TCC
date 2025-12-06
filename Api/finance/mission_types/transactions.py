
from datetime import timedelta
from typing import Any, Dict, Tuple

from django.db.models import Q
from django.utils import timezone

from .base import BaseMissionValidator


class TransactionConsistencyValidator(BaseMissionValidator):
    
    def calculate_progress(self) -> Dict[str, Any]:
        from ..models import Transaction
        
        min_frequency = self.mission.min_transaction_frequency or 3
        duration_weeks = (self.mission.duration_days + 6) // 7
        
        if not self.mission_progress.started_at:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão ainda não foi iniciada'
            }
        
        transaction_filter = Q(user=self.user, date__gte=self.mission_progress.started_at.date())
        if self.mission.transaction_type_filter != 'ALL':
            transaction_filter &= Q(type=self.mission.transaction_type_filter)
        
        weeks_meeting_criteria = 0
        current_date = self.mission_progress.started_at.date()
        end_date = min(timezone.now().date(), current_date + timedelta(days=self.mission.duration_days))
        
        while current_date < end_date:
            week_end = min(current_date + timedelta(days=7), end_date)
            week_transactions = Transaction.objects.filter(
                transaction_filter,
                date__gte=current_date,
                date__lt=week_end
            ).count()
            
            if week_transactions >= min_frequency:
                weeks_meeting_criteria += 1
            
            current_date = week_end
        
        progress = min(100, (weeks_meeting_criteria / duration_weeks) * 100)
        
        return {
            'progress_percentage': float(progress),
            'is_completed': weeks_meeting_criteria >= duration_weeks,
            'metrics': {
                'weeks_meeting_criteria': weeks_meeting_criteria,
                'target_weeks': duration_weeks,
                'min_frequency': min_frequency,
                'transaction_type': self.mission.transaction_type_filter
            },
            'message': f"{weeks_meeting_criteria}/{duration_weeks} semanas com consistência"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, "Parabéns! Você manteve consistência no registro de transações!"
        return False, "Continue registrando transações regularmente"


class PaymentDisciplineValidator(BaseMissionValidator):
    
    def calculate_progress(self) -> Dict[str, Any]:
        from ..models import Transaction
        
        if not self.mission.requires_payment_tracking:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão não requer rastreamento de pagamentos'
            }
        
        if not self.mission_progress.started_at:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão ainda não foi iniciada'
            }
        
        payments_count = Transaction.objects.filter(
            user=self.user,
            is_paid=True,
            date__gte=self.mission_progress.started_at.date()
        ).count()
        
        target_payments = self.mission.min_payments_count or 5
        progress = min(100, (payments_count / target_payments) * 100)
        
        return {
            'progress_percentage': float(progress),
            'is_completed': payments_count >= target_payments,
            'metrics': {
                'payments_count': payments_count,
                'target_payments': target_payments,
                'remaining': max(0, target_payments - payments_count)
            },
            'message': f"{payments_count}/{target_payments} pagamentos registrados"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, "Parabéns! Você manteve a disciplina nos pagamentos!"
        return False, "Continue registrando seus pagamentos"
