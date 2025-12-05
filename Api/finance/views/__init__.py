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
from .missions import MissionProgressViewSet, MissionViewSet
from .transactions import TransactionLinkViewSet, TransactionViewSet
from .admin_panel import (
    AdminDashboardView,
    AdminMissionsView,
    AdminMissionDetailView,
    AdminMissionToggleView,
    AdminGenerateMissionsView,
    AdminMissionTypeSchemasView,
    AdminMissionValidateView,
    AdminMissionSelectOptionsView,
    AdminCategoriesView,
    AdminCategoryDetailView,
    AdminUsersView,
    AdminUserDetailView,
    AdminUserToggleView,
)

__all__ = [
    # Categories
    'CategoryViewSet',
    # Transactions
    'TransactionViewSet',
    'TransactionLinkViewSet',
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
    # Admin Panel
    'AdminDashboardView',
    'AdminMissionsView',
    'AdminMissionDetailView',
    'AdminMissionToggleView',
    'AdminGenerateMissionsView',
    'AdminMissionTypeSchemasView',
    'AdminMissionValidateView',
    'AdminMissionSelectOptionsView',
    'AdminCategoriesView',
    'AdminCategoryDetailView',
    'AdminUsersView',
    'AdminUserDetailView',
    'AdminUserToggleView',
]
