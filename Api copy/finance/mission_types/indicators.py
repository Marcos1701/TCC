
from typing import Any, Dict, Tuple

from django.utils import timezone

from .base import BaseMissionValidator


class TPSImprovementMissionValidator(BaseMissionValidator):
    
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

# IndicatorMaintenanceValidator foi DEPRECADO
# Lógica de dias consecutivos removida - todas as missões agora usam apenas prazo (duration_days)
# A classe foi mantida apenas para referência histórica

# class IndicatorMaintenanceValidator(BaseMissionValidator):
#     """
#     DEPRECATED: Esta classe não é mais usada.
#     A lógica de "manter indicador por X dias consecutivos" foi simplificada.
#     Todas as missões agora completam imediatamente ao atingir a meta.
#     """
#     pass

