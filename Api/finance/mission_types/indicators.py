"""
Validadores para missões relacionadas a indicadores financeiros (TPS, RDR, ILI).
"""

from typing import Any, Dict, Tuple

from django.utils import timezone

from .base import BaseMissionValidator


class TPSImprovementMissionValidator(BaseMissionValidator):
    """
    Validador para missões de melhoria de Taxa de Poupança Pessoal.
    
    Foco: Aumentar % de economia sobre receita total.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        metrics = self.get_current_metrics()
        current_tps = float(metrics.get('tps', 0))
        target_tps = float(self.mission.target_tps or 20)
        initial_tps = float(self.mission_progress.initial_tps or 0)
        
        if target_tps <= initial_tps:
            progress = 100 if current_tps >= target_tps else 0
        else:
            improvement_needed = target_tps - initial_tps
            current_improvement = current_tps - initial_tps
            progress = min(100, max(0, (current_improvement / improvement_needed) * 100))
        
        return {
            'progress_percentage': progress,
            'is_completed': current_tps >= target_tps,
            'metrics': {
                'initial_tps': round(initial_tps, 2),
                'current_tps': round(current_tps, 2),
                'target_tps': round(target_tps, 2),
                'improvement': round(current_tps - initial_tps, 2),
                'needed_improvement': round(max(0, target_tps - current_tps), 2)
            },
            'message': f"Seu TPS está em {current_tps:.1f}% (meta: {target_tps:.1f}%)"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        metrics = self.get_current_metrics()
        current_tps = float(metrics.get('tps', 0))
        target_tps = float(self.mission.target_tps or 20)
        
        if current_tps >= target_tps:
            return True, f"Excelente! Seu TPS de {current_tps:.1f}% atingiu a meta de {target_tps:.1f}%!"
        
        return False, f"Continue melhorando seu TPS (atual: {current_tps:.1f}%, meta: {target_tps:.1f}%)"


class RDRReductionMissionValidator(BaseMissionValidator):
    """
    Validador para missões de redução de Razão Dívida-Receita.
    
    Foco: Reduzir comprometimento de renda com despesas recorrentes.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        metrics = self.get_current_metrics()
        current_rdr = float(metrics.get('rdr', 100))
        target_rdr = float(self.mission.target_rdr or 30)
        initial_rdr = float(self.mission_progress.initial_rdr or 100)
        
        if initial_rdr <= target_rdr:
            progress = 100 if current_rdr <= target_rdr else 0
        else:
            reduction_needed = initial_rdr - target_rdr
            current_reduction = initial_rdr - current_rdr
            progress = min(100, max(0, (current_reduction / reduction_needed) * 100))
        
        return {
            'progress_percentage': progress,
            'is_completed': current_rdr <= target_rdr,
            'metrics': {
                'initial_rdr': round(initial_rdr, 2),
                'current_rdr': round(current_rdr, 2),
                'target_rdr': round(target_rdr, 2),
                'reduction': round(initial_rdr - current_rdr, 2),
                'needed_reduction': round(max(0, current_rdr - target_rdr), 2)
            },
            'message': f"Seu RDR está em {current_rdr:.1f}% (meta: {target_rdr:.1f}%)"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        metrics = self.get_current_metrics()
        current_rdr = float(metrics.get('rdr', 100))
        target_rdr = float(self.mission.target_rdr or 30)
        
        if current_rdr <= target_rdr:
            return True, f"Parabéns! Seu RDR de {current_rdr:.1f}% está abaixo da meta de {target_rdr:.1f}%!"
        
        return False, f"Continue reduzindo seu RDR (atual: {current_rdr:.1f}%, meta: {target_rdr:.1f}%)"


class ILIBuildingMissionValidator(BaseMissionValidator):
    """
    Validador para missões de construção de Índice de Liquidez Imediata.
    
    Foco: Aumentar reserva de emergência em meses de despesas cobertas.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        metrics = self.get_current_metrics()
        current_ili = float(metrics.get('ili', 0))
        target_ili = float(self.mission.min_ili or 6)
        initial_ili = float(self.mission_progress.initial_ili or 0)
        
        if target_ili <= initial_ili:
            progress = 100 if current_ili >= target_ili else 0
        else:
            improvement_needed = target_ili - initial_ili
            current_improvement = current_ili - initial_ili
            progress = min(100, max(0, (current_improvement / improvement_needed) * 100))
        
        return {
            'progress_percentage': progress,
            'is_completed': current_ili >= target_ili,
            'metrics': {
                'initial_ili': round(initial_ili, 2),
                'current_ili': round(current_ili, 2),
                'target_ili': round(target_ili, 2),
                'improvement': round(current_ili - initial_ili, 2),
                'needed_improvement': round(max(0, target_ili - current_ili), 2)
            },
            'message': f"Sua reserva cobre {current_ili:.1f} meses (meta: {target_ili:.1f})"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        metrics = self.get_current_metrics()
        current_ili = float(metrics.get('ili', 0))
        target_ili = float(self.mission.min_ili or 6)
        
        if current_ili >= target_ili:
            return True, f"Fantástico! Sua reserva de {current_ili:.1f} meses atingiu a meta!"
        
        return False, f"Continue construindo sua reserva (atual: {current_ili:.1f}, meta: {target_ili:.1f})"


class IndicatorMaintenanceValidator(BaseMissionValidator):
    """
    Validador para missões de manutenção de indicadores.
    
    Foco: Manter TPS/RDR/ILI em nível específico por X dias consecutivos.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        from ..services import calculate_summary
        
        if not self.mission_progress.started_at:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão ainda não foi iniciada'
            }
        
        metrics = calculate_summary(self.user)
        indicators_status = []
        all_met = True
        
        if self.mission.target_tps is not None:
            current_tps = float(metrics.get('tps', 0))
            met = current_tps >= self.mission.target_tps
            indicators_status.append({
                'name': 'TPS',
                'current': current_tps,
                'target': self.mission.target_tps,
                'met': met
            })
            all_met = all_met and met
        
        if self.mission.target_rdr is not None:
            current_rdr = float(metrics.get('rdr', 100))
            met = current_rdr <= self.mission.target_rdr
            indicators_status.append({
                'name': 'RDR',
                'current': current_rdr,
                'target': self.mission.target_rdr,
                'met': met
            })
            all_met = all_met and met
        
        if self.mission.min_ili is not None or self.mission.max_ili is not None:
            current_ili = float(metrics.get('ili', 0))
            met_min = current_ili >= float(self.mission.min_ili) if self.mission.min_ili else True
            met_max = current_ili <= float(self.mission.max_ili) if self.mission.max_ili else True
            met = met_min and met_max
            indicators_status.append({
                'name': 'ILI',
                'current': current_ili,
                'target_min': float(self.mission.min_ili) if self.mission.min_ili else None,
                'target_max': float(self.mission.max_ili) if self.mission.max_ili else None,
                'met': met
            })
            all_met = all_met and met
        
        min_days = self.mission.min_consecutive_days or self.mission.duration_days
        elapsed_days = (timezone.now() - self.mission_progress.started_at).days
        days_maintained = elapsed_days if all_met else 0
        
        progress = min(100, (days_maintained / min_days) * 100)
        
        return {
            'progress_percentage': float(progress),
            'is_completed': days_maintained >= min_days,
            'metrics': {
                'indicators': indicators_status,
                'days_maintained': days_maintained,
                'target_days': min_days,
                'all_met': all_met
            },
            'message': f"Indicadores mantidos por {days_maintained}/{min_days} dias"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, "Parabéns! Você manteve seus indicadores no nível adequado!"
        if not result['metrics']['all_met']:
            pending = [ind['name'] for ind in result['metrics']['indicators'] if not ind['met']]
            return False, f"Ajuste os indicadores: {', '.join(pending)}"
        return False, "Continue mantendo seus indicadores"
