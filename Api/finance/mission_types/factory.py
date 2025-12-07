
import logging
from typing import Any, Dict

from django.utils import timezone

from .base import BaseMissionValidator
from .onboarding import OnboardingMissionValidator
from .indicators import (
    TPSImprovementMissionValidator,
    RDRReductionMissionValidator,
    ILIBuildingMissionValidator,
)
from .categories import CategoryReductionValidator, CategoryLimitValidator
from .transactions import TransactionConsistencyValidator, PaymentDisciplineValidator
from .advanced import AdvancedMissionValidator, MultiCriteriaValidator


logger = logging.getLogger(__name__)


# Mapeamento simplificado: mission_type → validator
# Esta é a ÚNICA fonte de verdade para seleção de validadores
VALIDATOR_MAP = {
    'ONBOARDING': OnboardingMissionValidator,
    'TPS_IMPROVEMENT': TPSImprovementMissionValidator,
    'RDR_REDUCTION': RDRReductionMissionValidator,
    'ILI_BUILDING': ILIBuildingMissionValidator,
    'CATEGORY_REDUCTION': CategoryReductionValidator,
}

# Validadores por validation_type (para casos com categoria específica)
VALIDATION_TYPE_MAP = {
    'CATEGORY_LIMIT': CategoryLimitValidator,
    'TRANSACTION_CONSISTENCY': TransactionConsistencyValidator,
    'PAYMENT_COUNT': PaymentDisciplineValidator,
}


class MissionValidatorFactory:
    """Factory simplificada para criar validadores de missão.
    
    A seleção do validador é baseada primariamente no mission_type.
    O validation_type só é usado como fallback para casos específicos.
    """
    
    @classmethod
    def create_validator(cls, mission, user, mission_progress) -> BaseMissionValidator:
        """Cria e retorna o validador correto para a missão."""
        
        # 1. Primeiro, tenta pelo mission_type (preferido)
        validator_class = VALIDATOR_MAP.get(mission.mission_type)
        
        if validator_class:
            return validator_class(mission, user, mission_progress)
        
        # 2. Se não encontrou, tenta pelo validation_type (fallback)
        if mission.validation_type:
            validator_class = VALIDATION_TYPE_MAP.get(mission.validation_type)
            if validator_class:
                return validator_class(mission, user, mission_progress)
        
        # 3. Fallback final: MultiCriteriaValidator
        logger.warning(
            f"Tipo de missão desconhecido: {mission.mission_type} "
            f"(validation_type: {mission.validation_type}), usando MultiCriteriaValidator"
        )
        return MultiCriteriaValidator(mission, user, mission_progress)


def update_single_mission_progress(mission_progress) -> Dict[str, Any]:
    from decimal import Decimal
    from ..models import MissionProgress as MissionProgressModel
    
    validator = MissionValidatorFactory.create_validator(
        mission_progress.mission,
        mission_progress.user,
        mission_progress
    )
    
    result = validator.calculate_progress()
    
    mission_progress.progress = Decimal(str(result['progress_percentage']))
    
    if result['is_completed'] and not mission_progress.completed_at:
        is_valid, message = validator.validate_completion()
        if is_valid:
            mission_progress.completed_at = timezone.now()
            mission_progress.status = MissionProgressModel.Status.COMPLETED
            logger.info(f"Missão completada: {mission_progress.mission.title} - {message}")
    
    mission_progress.save()
    
    return result
