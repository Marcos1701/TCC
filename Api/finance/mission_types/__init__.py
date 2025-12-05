"""
Package mission_types - Sistema de validação de missões.

Arquitetura:
- BaseMissionValidator: Classe abstrata base
- Validators especializados por tipo de missão
- MissionValidatorFactory: Factory para instanciar validadores
"""

from .base import BaseMissionValidator
from .factory import MissionValidatorFactory, update_single_mission_progress
from .onboarding import OnboardingMissionValidator
from .indicators import (
    TPSImprovementMissionValidator,
    RDRReductionMissionValidator,
    ILIBuildingMissionValidator,
    IndicatorMaintenanceValidator,
)
from .categories import (
    CategoryReductionValidator,
    CategoryLimitValidator,
)
from .goals import (
    GoalProgressValidator,
    GoalContributionValidator,
)
from .transactions import (
    TransactionConsistencyValidator,
    PaymentDisciplineValidator,
)
from .advanced import (
    AdvancedMissionValidator,
    MultiCriteriaValidator,
)

__all__ = [
    'BaseMissionValidator',
    'MissionValidatorFactory',
    'update_single_mission_progress',
    'OnboardingMissionValidator',
    'TPSImprovementMissionValidator',
    'RDRReductionMissionValidator',
    'ILIBuildingMissionValidator',
    'IndicatorMaintenanceValidator',
    'CategoryReductionValidator',
    'CategoryLimitValidator',
    'GoalProgressValidator',
    'GoalContributionValidator',
    'TransactionConsistencyValidator',
    'PaymentDisciplineValidator',
    'AdvancedMissionValidator',
    'MultiCriteriaValidator',
]
