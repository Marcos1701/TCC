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
    # Admin Panel
    AdminDashboardView,
    AdminMissionsView,
    AdminMissionDetailView,
    AdminMissionToggleView,
    AdminGenerateMissionsView,
    AdminCategoriesView,
    AdminCategoryDetailView,
    AdminUsersView,
    AdminUserDetailView,
    AdminUserToggleView,
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
    path("user/me/", ProfileView.as_view(), name="user-me"),  # Alias para compatibilidade
    path("onboarding/simplified/", SimplifiedOnboardingView.as_view(), name="simplified-onboarding"),
    path("xp-history/", XPHistoryView.as_view(), name="xp-history"),
    
    # Painel Administrativo (requer is_staff=True)
    path("admin-panel/", AdminDashboardView.as_view(), name="admin-dashboard"),
    path("admin-panel/missoes/", AdminMissionsView.as_view(), name="admin-missions"),
    path("admin-panel/missoes/<int:pk>/", AdminMissionDetailView.as_view(), name="admin-mission-detail"),
    path("admin-panel/missoes/<int:pk>/toggle/", AdminMissionToggleView.as_view(), name="admin-mission-toggle"),
    path("admin-panel/missoes/gerar/", AdminGenerateMissionsView.as_view(), name="admin-generate-missions"),
    path("admin-panel/categorias/", AdminCategoriesView.as_view(), name="admin-categories"),
    path("admin-panel/categorias/<int:pk>/", AdminCategoryDetailView.as_view(), name="admin-category-detail"),
    path("admin-panel/usuarios/", AdminUsersView.as_view(), name="admin-users"),
    path("admin-panel/usuarios/<int:pk>/", AdminUserDetailView.as_view(), name="admin-user-detail"),
    path("admin-panel/usuarios/<int:pk>/toggle/", AdminUserToggleView.as_view(), name="admin-user-toggle"),
]
