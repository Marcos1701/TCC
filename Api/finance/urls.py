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
)

router = DefaultRouter()
router.register(r"categories", CategoryViewSet, basename="category")
router.register(r"transactions", TransactionViewSet, basename="transaction")
router.register(r"goals", GoalViewSet, basename="goal")
router.register(r"missions", MissionViewSet, basename="mission")
router.register(r"mission-progress", MissionProgressViewSet, basename="mission-progress")
router.register(r"user-profiles", UserProfileViewSet, basename="user-profile")
router.register(r"transaction-links", TransactionLinkViewSet, basename="transaction-link")
router.register(r"dashboard", DashboardViewSet, basename="dashboard")

urlpatterns = [
    path("", include(router.urls)),
    path("auth/register/", RegisterView.as_view(), name="register"),
    path("auth/profile/", ProfileView.as_view(), name="profile"),
    path("profile/", ProfileView.as_view(), name="profile-alias"),  # Alias para compatibilidade
    path("onboarding/simplified/", SimplifiedOnboardingView.as_view(), name="simplified-onboarding"),
    path("xp-history/", XPHistoryView.as_view(), name="xp-history"),
]
