
import logging
from typing import Any, Dict

from django.utils import timezone

from .base import BaseMissionValidator
from .onboarding import OnboardingMissionValidator
from .indicators import (
    TPSImprovementMissionValidator,
    RDRReductionMissionValidator,
    ILIBuildingMissionValidator,
    IndicatorMaintenanceValidator,
)
from .categories import CategoryReductionValidator, CategoryLimitValidator
from .transactions import TransactionConsistencyValidator, PaymentDisciplineValidator
from .advanced import AdvancedMissionValidator, MultiCriteriaValidator


logger = logging.getLogger(__name__)


class MissionValidatorFactory:
    
    _validators = {
        'ONBOARDING': OnboardingMissionValidator,
        'TPS_IMPROVEMENT': TPSImprovementMissionValidator,
        'RDR_REDUCTION': RDRReductionMissionValidator,
        'ILI_BUILDING': ILIBuildingMissionValidator,
        'ADVANCED': AdvancedMissionValidator,
        'ONBOARDING_TRANSACTIONS': OnboardingMissionValidator,
        'ONBOARDING_CATEGORIES': OnboardingMissionValidator,
        'CATEGORY_REDUCTION': CategoryReductionValidator,
        'CATEGORY_SPENDING_LIMIT': CategoryLimitValidator,
        'CATEGORY_ELIMINATION': CategoryLimitValidator,
        'SAVINGS_STREAK': TransactionConsistencyValidator,
        'EXPENSE_CONTROL': CategoryLimitValidator,
        'INCOME_TRACKING': TransactionConsistencyValidator,
        'PAYMENT_DISCIPLINE': PaymentDisciplineValidator,
        'FINANCIAL_HEALTH': MultiCriteriaValidator,
        'WEALTH_BUILDING': MultiCriteriaValidator,
    }
    
    _validation_type_validators = {
        'CATEGORY_REDUCTION': CategoryReductionValidator,
        'CATEGORY_LIMIT': CategoryLimitValidator,
        'CATEGORY_ZERO': CategoryLimitValidator,
        'TRANSACTION_COUNT': OnboardingMissionValidator,
        'TRANSACTION_CONSISTENCY': TransactionConsistencyValidator,
        'PAYMENT_COUNT': PaymentDisciplineValidator,
        'INDICATOR_THRESHOLD': AdvancedMissionValidator,
        'INDICATOR_IMPROVEMENT': TPSImprovementMissionValidator,
        'INDICATOR_MAINTENANCE': IndicatorMaintenanceValidator,
        'MULTI_CRITERIA': MultiCriteriaValidator,
    }
    
    @classmethod
    def create_validator(cls, mission, user, mission_progress) -> BaseMissionValidator:
        validator_class = cls._validation_type_validators.get(mission.validation_type)
        
        if validator_class is None:
            validator_class = cls._validators.get(mission.mission_type)
        
        if validator_class is None:
            logger.warning(f"Tipo de missão desconhecido: {mission.mission_type}, usando MultiCriteriaValidator")
            validator_class = MultiCriteriaValidator
        
        return validator_class(mission, user, mission_progress)


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
