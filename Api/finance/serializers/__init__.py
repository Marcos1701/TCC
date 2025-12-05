"""
Package de serializers do finance.
Organizado em módulos por domínio.
"""

from .category import CategorySerializer
from .transaction import (
    TransactionSerializer,
    TransactionLinkSerializer,
    TransactionLinkSummarySerializer,
)
from .mission import MissionSerializer, MissionProgressSerializer
from .dashboard import (
    DashboardSummarySerializer,
    CategoryBreakdownSerializer,
    CashflowPointSerializer,
    IndicatorInsightSerializer,
    UserProfileSerializer,
    DashboardSerializer,
)

__all__ = [
    'CategorySerializer',
    'TransactionSerializer',
    'MissionSerializer',
    'MissionProgressSerializer',
    'DashboardSummarySerializer',
    'CategoryBreakdownSerializer',
    'CashflowPointSerializer',
    'IndicatorInsightSerializer',
    'UserProfileSerializer',
    'DashboardSerializer',
    'TransactionLinkSerializer',
    'TransactionLinkSummarySerializer',
]
