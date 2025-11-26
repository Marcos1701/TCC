"""
Validadores para missões avançadas e com múltiplos critérios.
"""

from decimal import Decimal
from typing import Any, Dict, Tuple

from django.db.models import Sum

from .base import BaseMissionValidator


class AdvancedMissionValidator(BaseMissionValidator):
    """
    Validador para missões avançadas com múltiplos critérios.
    
    Foco: Desafios complexos que combinam TPS, RDR, ILI e outras métricas.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        metrics = self.get_current_metrics()
        
        criteria = []
        completed_criteria = 0
        
        if self.mission.target_tps is not None:
            current_tps = float(metrics.get('tps', 0))
            target_tps = float(self.mission.target_tps)
            met = current_tps >= target_tps
            criteria.append({
                'name': 'TPS',
                'current': current_tps,
                'target': target_tps,
                'met': met
            })
            if met:
                completed_criteria += 1
        
        if self.mission.target_rdr is not None:
            current_rdr = float(metrics.get('rdr', 100))
            target_rdr = float(self.mission.target_rdr)
            met = current_rdr <= target_rdr
            criteria.append({
                'name': 'RDR',
                'current': current_rdr,
                'target': target_rdr,
                'met': met
            })
            if met:
                completed_criteria += 1
        
        if self.mission.min_ili is not None:
            current_ili = float(metrics.get('ili', 0))
            target_ili = float(self.mission.min_ili)
            met = current_ili >= target_ili
            criteria.append({
                'name': 'ILI',
                'current': current_ili,
                'target': target_ili,
                'met': met
            })
            if met:
                completed_criteria += 1
        
        total_criteria = len(criteria) or 1
        progress = (completed_criteria / total_criteria) * 100
        
        return {
            'progress_percentage': progress,
            'is_completed': completed_criteria == total_criteria,
            'metrics': {
                'criteria': criteria,
                'completed': completed_criteria,
                'total': total_criteria
            },
            'message': f"Você atendeu {completed_criteria} de {total_criteria} critérios"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        
        if result['is_completed']:
            return True, "Parabéns! Você completou todos os critérios desta missão avançada!"
        
        criteria = result['metrics']['criteria']
        pending = [c['name'] for c in criteria if not c['met']]
        
        return False, f"Continue trabalhando em: {', '.join(pending)}"


class MultiCriteriaValidator(BaseMissionValidator):
    """
    Validador para missões com múltiplos critérios simultâneos.
    
    Foco: Combinar validações de diferentes tipos (categorias + metas + indicadores).
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        if not self.mission_progress.started_at:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão ainda não foi iniciada'
            }
        
        criteria_results = []
        total_progress = 0
        criteria_count = 0
        
        if self.mission.target_categories.exists():
            from ..models import Transaction
            for category in self.mission.target_categories.all():
                spending = Transaction.objects.filter(
                    user=self.user,
                    category=category,
                    type='EXPENSE',
                    date__gte=self.mission_progress.started_at.date()
                ).aggregate(total=Sum('amount'))['total'] or Decimal('0')
                
                limit = self.mission.category_spending_limit or Decimal('500')
                met = spending <= limit
                criteria_results.append({
                    'type': 'category',
                    'name': category.name,
                    'met': met,
                    'value': float(spending),
                    'target': float(limit)
                })
                if met:
                    total_progress += 100
                criteria_count += 1
        
        if self.mission.target_goals.exists():
            for goal in self.mission.target_goals.all():
                goal_progress = (goal.current_amount / goal.target_amount * 100) if goal.target_amount > 0 else 0
                target_progress = float(self.mission.goal_progress_target or Decimal('50'))
                met = goal_progress >= target_progress
                criteria_results.append({
                    'type': 'goal',
                    'name': goal.title,
                    'met': met,
                    'value': float(goal_progress),
                    'target': target_progress
                })
                if met:
                    total_progress += 100
                criteria_count += 1
        
        from ..services import calculate_summary
        metrics = calculate_summary(self.user)
        
        if self.mission.target_tps is not None:
            current_tps = float(metrics.get('tps', 0))
            met = current_tps >= self.mission.target_tps
            criteria_results.append({
                'type': 'indicator',
                'name': 'TPS',
                'met': met,
                'value': current_tps,
                'target': self.mission.target_tps
            })
            if met:
                total_progress += 100
            criteria_count += 1
        
        if self.mission.target_rdr is not None:
            current_rdr = float(metrics.get('rdr', 100))
            met = current_rdr <= self.mission.target_rdr
            criteria_results.append({
                'type': 'indicator',
                'name': 'RDR',
                'met': met,
                'value': current_rdr,
                'target': self.mission.target_rdr
            })
            if met:
                total_progress += 100
            criteria_count += 1
        
        if criteria_count == 0:
            criteria_count = 1
        
        avg_progress = total_progress / criteria_count
        all_met = all(c['met'] for c in criteria_results)
        
        return {
            'progress_percentage': float(avg_progress),
            'is_completed': all_met,
            'metrics': {
                'criteria': criteria_results,
                'total_criteria': criteria_count,
                'met_criteria': sum(1 for c in criteria_results if c['met'])
            },
            'message': f"{sum(1 for c in criteria_results if c['met'])}/{criteria_count} critérios atendidos"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, "Parabéns! Você completou todos os critérios desta missão complexa!"
        pending = [c['name'] for c in result['metrics']['criteria'] if not c['met']]
        return False, f"Continue trabalhando em: {', '.join(pending)}"
