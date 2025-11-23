from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    CategoryViewSet,
    DashboardViewSet,
    GoalViewSet,
    MissionProgressViewSet,
    MissionViewSet,
    ProfileView,
    RegisterView,
    SimplifiedOnboardingView,
    TransactionLinkViewSet,
    TransactionViewSet,
    UserProfileViewSet,
    XPHistoryView,
    FriendshipViewSet,
    LeaderboardViewSet,
    AdminStatsViewSet,
    AdminUserManagementViewSet,
    AchievementViewSet,
)

router = DefaultRouter()
router.register(r"categories", CategoryViewSet, basename="category")
    path("", include(router.urls)),
]
