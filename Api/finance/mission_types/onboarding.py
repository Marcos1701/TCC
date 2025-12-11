
from typing import Any, Dict, Tuple

from .base import BaseMissionValidator


class OnboardingMissionValidator(BaseMissionValidator):
    
    def calculate_progress(self) -> Dict[str, Any]:
        from django.db.models import Q
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
        
        # Constrói filtro dinâmico baseado em transaction_type_filter
        filter_query = Q(user=self.user, created_at__gte=self.mission_progress.started_at)
        
        type_filter = self.mission.transaction_type_filter
        if type_filter == 'ALL':
            filter_query &= Q(type__in=['INCOME', 'EXPENSE'])
        elif type_filter == 'DEPOSIT':
            # Aportes: transações de categorias de poupança/investimento
            filter_query &= Q(category__group__in=['SAVINGS', 'INVESTMENT'])
        elif type_filter == 'PAYMENT':
            # Pagamentos: transações marcadas como pagas
            filter_query &= Q(is_paid=True)
        else:
            # INCOME ou EXPENSE específico
            filter_query &= Q(type=type_filter)
        
        transactions_count = Transaction.objects.filter(filter_query).count()
        
        target = self.mission.min_transactions or 10
        progress = min(100, (transactions_count / target) * 100)
        
        # Monta mensagem contextual baseada no tipo
        type_labels = {
            'ALL': 'transações',
            'INCOME': 'receitas',
            'EXPENSE': 'despesas',
            'DEPOSIT': 'aportes',
            'PAYMENT': 'pagamentos',
        }
        type_label = type_labels.get(type_filter, 'transações')
        
        return {
            'progress_percentage': progress,
            'is_completed': transactions_count >= target,
            'metrics': {
                'transactions_registered': transactions_count,
                'target_transactions': target,
                'remaining': max(0, target - transactions_count),
                'transaction_type': type_filter,
            },
            'message': f"Você registrou {transactions_count} de {target} {type_label}"
        }

    
    def validate_completion(self) -> Tuple[bool, str]:
        from django.db.models import Q
        from ..models import Transaction
        
        if not self.mission_progress.started_at:
            return False, 'Missão ainda não foi iniciada'
        
        # Usa mesma lógica de filtro dinâmico
        filter_query = Q(user=self.user, created_at__gte=self.mission_progress.started_at)
        
        type_filter = self.mission.transaction_type_filter
        if type_filter == 'ALL':
            filter_query &= Q(type__in=['INCOME', 'EXPENSE'])
        elif type_filter == 'DEPOSIT':
            filter_query &= Q(category__group__in=['SAVINGS', 'INVESTMENT'])
        elif type_filter == 'PAYMENT':
            filter_query &= Q(is_paid=True)
        else:
            filter_query &= Q(type=type_filter)
        
        transactions_count = Transaction.objects.filter(filter_query).count()
        target = self.mission.min_transactions or 10
        
        type_labels = {
            'ALL': 'transações',
            'INCOME': 'receitas',
            'EXPENSE': 'despesas',
            'DEPOSIT': 'aportes',
            'PAYMENT': 'pagamentos',
        }
        type_label = type_labels.get(type_filter, 'transações')
        
        if transactions_count >= target:
            return True, f"Parabéns! Você registrou {transactions_count} {type_label}!"
        
        return False, f"Continue registrando {type_label} ({transactions_count}/{target})"

