
from typing import Any, Dict, Tuple

from .base import BaseMissionValidator


class OnboardingMissionValidator(BaseMissionValidator):
    
    def calculate_progress(self) -> Dict[str, Any]:
        from ..models import Transaction
        
        if not self.mission_progress.started_at:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {
                    'transactions_registered': 0,
                    'target_transactions': self.mission.min_transactions or 10,
                    'remaining': self.mission.min_transactions or 10
                },
                'message': 'Missão ainda não foi iniciada'
            }
        
        transactions_count = Transaction.objects.filter(
            user=self.user,
            created_at__gte=self.mission_progress.started_at
        ).count()
        
        target = self.mission.min_transactions or 10
        progress = min(100, (transactions_count / target) * 100)
        
        return {
            'progress_percentage': progress,
            'is_completed': transactions_count >= target,
            'metrics': {
                'transactions_registered': transactions_count,
                'target_transactions': target,
                'remaining': max(0, target - transactions_count)
            },
            'message': f"Você registrou {transactions_count} de {target} transações"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        from ..models import Transaction
        
        if not self.mission_progress.started_at:
            return False, 'Missão ainda não foi iniciada'
        
        transactions_count = Transaction.objects.filter(
            user=self.user,
            created_at__gte=self.mission_progress.started_at
        ).count()
        
        target = self.mission.min_transactions or 10
        
        if transactions_count >= target:
            return True, f"Parabéns! Você registrou {transactions_count} transações!"
        
        return False, f"Continue registrando transações ({transactions_count}/{target})"
