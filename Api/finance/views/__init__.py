"""
Package de views do módulo finance.

Exporta todos os ViewSets e Views para uso no urls.py.
"""

from .auth import (
    ProfileView,
    RegisterView,
    SimplifiedOnboardingView,
    UserProfileViewSet,
    XPHistoryView,
)
from .categories import CategoryViewSet
from .dashboard import DashboardViewSet
from .goals import GoalViewSet
from .missions import MissionProgressViewSet, MissionViewSet
from .transactions import TransactionLinkViewSet, TransactionViewSet

__all__ = [
    # Categories
    'CategoryViewSet',
    # Transactions
    'TransactionViewSet',
    'TransactionLinkViewSet',
    # Goals
    'GoalViewSet',
    # Missions
    'MissionViewSet',
    'MissionProgressViewSet',
    # Dashboard
    'DashboardViewSet',
    # Auth & Profile
    'ProfileView',
    'XPHistoryView',
    'SimplifiedOnboardingView',
    'RegisterView',
    'UserProfileViewSet',
]
