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
    TransactionLinkViewSet,
    TransactionViewSet,
    UserProfileViewSet,
    XPHistoryView,
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

urlpatterns = [
    path("auth/register/", RegisterView.as_view(), name="register"),
    path("profile/", ProfileView.as_view(), name="profile"),
    path("profile/xp-history/", XPHistoryView.as_view(), name="xp-history"),
    path("", include(router.urls)),
]
