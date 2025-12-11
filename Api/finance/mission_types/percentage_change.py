"""
Validadores para missões de variação percentual (aumento/redução).
"""

from datetime import date, timedelta
from calendar import monthrange
from decimal import Decimal
from typing import Any, Dict, Tuple

from django.db.models import Sum, Q
from django.utils import timezone

from .base import BaseMissionValidator


class PercentageChangeValidator(BaseMissionValidator):
    """
    Valida missões que exigem variação percentual (aumento ou redução).
    
    Suporta:
    - INCOME: aumento de receitas
    - EXPENSE: redução de despesas  
    - DEPOSIT: aumento de aportes
    
    Usa validation_details para:
    - selected_category_ids: categorias a monitorar (vazio = todas)
    - comparison_mode: 'previous_vs_current' ou 'current_vs_next'
    - baseline_month: mês base para comparação
    - target_month: mês alvo para atingir a meta
    """
    
    def _get_transaction_filter(self) -> Q:
        """Retorna filtro de transações baseado em transaction_type_filter e categorias."""
        # Prioriza tipo de validation_details, depois mission
        details = self.mission_progress.validation_details or {}
        type_filter = details.get('transaction_type_filter') or self.mission.transaction_type_filter or 'EXPENSE'
        
        base_filter = Q()
        if type_filter == 'INCOME':
            base_filter = Q(type='INCOME')
        elif type_filter == 'EXPENSE':
            base_filter = Q(type='EXPENSE')
        elif type_filter == 'DEPOSIT':
            base_filter = Q(category__group__in=['SAVINGS', 'INVESTMENT'])
        else:
            base_filter = Q(type='EXPENSE')
        
        # Aplica filtro de categorias selecionadas
        category_ids = details.get('selected_category_ids', [])
        if category_ids:
            base_filter &= Q(category_id__in=category_ids)
        
        return base_filter
    
    def _get_baseline_value(self) -> Decimal:
        """Retorna baseline salvo em validation_details ou calcula."""
        details = self.mission_progress.validation_details or {}
        
        # Se já temos baseline salvo, usa ele
        if 'baseline_value' in details:
            return Decimal(str(details['baseline_value']))
        
        # Fallback: usa campo baseline_category_spending
        if self.mission_progress.baseline_category_spending:
            return self.mission_progress.baseline_category_spending
        
        return Decimal('0')
    
    def _get_current_value(self) -> Decimal:
        """Calcula valor do mês alvo (definido em validation_details)."""
        from ..models import Transaction
        
        details = self.mission_progress.validation_details or {}
        target_month = details.get('target_month')
        
        if not target_month:
            # Fallback: período desde início da missão
            if not self.mission_progress.started_at:
                return Decimal('0')
            
            filter_query = Q(
                user=self.user,
                date__gte=self.mission_progress.started_at.date(),
                date__lte=timezone.now().date(),
            ) & self._get_transaction_filter()
            
            result = Transaction.objects.filter(filter_query).aggregate(
                total=Sum('amount')
            )
            return result['total'] or Decimal('0')
        
        # Usa target_month específico
        year, month = map(int, target_month.split('-'))
        month_start = date(year, month, 1)
        
        # Último dia do mês ou hoje se for mês atual
        now = timezone.now()
        if year == now.year and month == now.month:
            month_end = now.date()
        else:
            last_day = monthrange(year, month)[1]
            month_end = date(year, month, last_day)
        
        filter_query = Q(
            user=self.user,
            date__gte=month_start,
            date__lte=month_end,
        ) & self._get_transaction_filter()
        
        result = Transaction.objects.filter(filter_query).aggregate(
            total=Sum('amount')
        )
        return result['total'] or Decimal('0')
    
    def calculate_progress(self) -> Dict[str, Any]:
        if not self.mission_progress.started_at:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão ainda não foi iniciada'
            }
        
        details = self.mission_progress.validation_details or {}
        type_filter = details.get('transaction_type_filter') or self.mission.transaction_type_filter or 'EXPENSE'
        target_change = float(self.mission.target_percentage_change or 10)
        
        baseline = float(self._get_baseline_value())
        current = float(self._get_current_value())
        
        # Se não há baseline, não dá para calcular variação
        if baseline == 0:
            comparison_mode = details.get('comparison_mode', 'previous_vs_current')
            if comparison_mode == 'current_vs_next':
                return {
                    'progress_percentage': 0,
                    'is_completed': False,
                    'metrics': {
                        'baseline': 0,
                        'current': current,
                        'target_change': target_change,
                        'actual_change': 0,
                    },
                    'message': 'Aguardando fim do mês para primeira comparação'
                }
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {
                    'baseline': 0,
                    'current': current,
                    'target_change': target_change,
                    'actual_change': 0,
                },
                'message': 'Sem dados históricos para comparação'
            }
        
        # Calcula variação percentual
        actual_change = ((current - baseline) / baseline) * 100
        
        # Define progresso baseado no tipo
        # EXPENSE: queremos redução (actual_change negativo é bom)
        # INCOME/DEPOSIT: queremos aumento (actual_change positivo é bom)
        if type_filter == 'EXPENSE':
            # Para despesas, redução = progresso positivo
            if actual_change <= 0:
                progress = min(100, (abs(actual_change) / target_change) * 100)
            else:
                progress = 0
            is_completed = actual_change <= -target_change
        else:
            # Para receitas/aportes, aumento = progresso positivo
            if actual_change >= 0:
                progress = min(100, (actual_change / target_change) * 100)
            else:
                progress = 0
            is_completed = actual_change >= target_change
        
        # Monta mensagem contextual
        type_labels = {
            'INCOME': 'receitas',
            'EXPENSE': 'despesas',
            'DEPOSIT': 'aportes',
        }
        type_label = type_labels.get(type_filter, 'valores')
        
        # Informação sobre categorias
        selection_type = details.get('selection_type', 'all')
        category_info = ""
        if selection_type == 'specific':
            category_ids = details.get('selected_category_ids', [])
            category_info = f" em {len(category_ids)} categoria(s)"
        
        if type_filter == 'EXPENSE':
            if actual_change < 0:
                action = 'reduziu'
                message = f"Você {action} {abs(actual_change):.1f}%{category_info} em {type_label} (meta: -{target_change}%)"
            else:
                action = 'aumentou'
                message = f"Gastos aumentaram {actual_change:.1f}%{category_info}. Tente reduzir {target_change}%"
        else:
            if actual_change > 0:
                action = 'aumentou'
                message = f"Você {action} {actual_change:.1f}%{category_info} em {type_label} (meta: +{target_change}%)"
            else:
                action = 'reduziu'
                message = f"{type_label.capitalize()} reduziram {abs(actual_change):.1f}%{category_info}. Tente aumentar {target_change}%"
        
        return {
            'progress_percentage': float(progress),
            'is_completed': is_completed,
            'metrics': {
                'baseline': round(baseline, 2),
                'current': round(current, 2),
                'target_change': target_change,
                'actual_change': round(actual_change, 2),
                'transaction_type': type_filter,
                'selection_type': selection_type,
                'comparison_mode': details.get('comparison_mode', 'previous_vs_current'),
                'baseline_month': details.get('baseline_month', ''),
                'target_month': details.get('target_month', ''),
            },
            'message': message
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        
        details = self.mission_progress.validation_details or {}
        type_filter = details.get('transaction_type_filter') or self.mission.transaction_type_filter or 'EXPENSE'
        type_labels = {
            'INCOME': 'receitas',
            'EXPENSE': 'despesas',
            'DEPOSIT': 'aportes',
        }
        type_label = type_labels.get(type_filter, 'valores')
        
        if result['is_completed']:
            actual = result['metrics'].get('actual_change', 0)
            if type_filter == 'EXPENSE':
                return True, f"Parabéns! Você reduziu {abs(actual):.1f}% em {type_label}!"
            else:
                return True, f"Parabéns! Você aumentou {actual:.1f}% em {type_label}!"
        
        return False, result['message']
