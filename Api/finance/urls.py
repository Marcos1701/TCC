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
)

router = DefaultRouter()
router.register(r"categories", CategoryViewSet, basename="category")
router.register(r"transactions", TransactionViewSet, basename="transaction")
router.register(r"transaction-links", TransactionLinkViewSet, basename="transaction-link")
router.register(r"goals", GoalViewSet, basename="goal")
router.register(r"missions", MissionViewSet, basename="mission")
router.register(r"mission-progress", MissionProgressViewSet, basename="mission-progress")
router.register(r"dashboard", DashboardViewSet, basename="dashboard")
router.register(r"user", UserProfileViewSet, basename="user")
router.register(r"friendships", FriendshipViewSet, basename="friendship")
router.register(r"leaderboard", LeaderboardViewSet, basename="leaderboard")
router.register(r"admin-stats", AdminStatsViewSet, basename="admin-stats")
router.register(r"admin/users", AdminUserManagementViewSet, basename="admin-users")

urlpatterns = [
    path("auth/register/", RegisterView.as_view(), name="register"),
    path("onboarding/simplified/", SimplifiedOnboardingView.as_view(), name="simplified-onboarding"),
    path("profile/", ProfileView.as_view(), name="profile"),
    path("profile/xp-history/", XPHistoryView.as_view(), name="xp-history"),
    path("", include(router.urls)),
]
