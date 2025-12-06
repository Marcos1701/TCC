from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    CategoryViewSet,
    DashboardViewSet,
    MissionProgressViewSet,
    MissionViewSet,
    ProfileView,
    RegisterView,
    SimplifiedOnboardingView,
    TransactionLinkViewSet,
    TransactionViewSet,
    UserProfileViewSet,
    XPHistoryView,
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

router = DefaultRouter()
router.register(r"categories", CategoryViewSet, basename="category")
router.register(r"transactions", TransactionViewSet, basename="transaction")
router.register(r"missions", MissionViewSet, basename="mission")
router.register(r"mission-progress", MissionProgressViewSet, basename="mission-progress")
router.register(r"user-profiles", UserProfileViewSet, basename="user-profile")
router.register(r"user", UserProfileViewSet, basename="user")
router.register(r"transaction-links", TransactionLinkViewSet, basename="transaction-link")
router.register(r"dashboard", DashboardViewSet, basename="dashboard")

urlpatterns = [
    path("", include(router.urls)),
    path("auth/register/", RegisterView.as_view(), name="register"),
    path("auth/profile/", ProfileView.as_view(), name="profile"),
    path("profile/", ProfileView.as_view(), name="profile-alias"),
    path("onboarding/simplified/", SimplifiedOnboardingView.as_view(), name="simplified-onboarding"),
    path("xp-history/", XPHistoryView.as_view(), name="xp-history"),
    
    path("admin-panel/", AdminDashboardView.as_view(), name="admin-dashboard"),
    path("admin-panel/missoes/", AdminMissionsView.as_view(), name="admin-missions"),
    path("admin-panel/missoes/<int:pk>/", AdminMissionDetailView.as_view(), name="admin-mission-detail"),
    path("admin-panel/missoes/<int:pk>/toggle/", AdminMissionToggleView.as_view(), name="admin-mission-toggle"),
    path("admin-panel/missoes/gerar/", AdminGenerateMissionsView.as_view(), name="admin-generate-missions"),
    path("admin-panel/missoes/tipos/", AdminMissionTypeSchemasView.as_view(), name="admin-mission-types"),
    path("admin-panel/missoes/tipos/<str:mission_type>/", AdminMissionTypeSchemasView.as_view(), name="admin-mission-type-detail"),
    path("admin-panel/missoes/validar/", AdminMissionValidateView.as_view(), name="admin-mission-validate"),
    path("admin-panel/missoes/opcoes-selecao/", AdminMissionSelectOptionsView.as_view(), name="admin-mission-select-options"),
    path("admin-panel/categorias/", AdminCategoriesView.as_view(), name="admin-categories"),
    path("admin-panel/categorias/<int:pk>/", AdminCategoryDetailView.as_view(), name="admin-category-detail"),
    path("admin-panel/usuarios/", AdminUsersView.as_view(), name="admin-users"),
    path("admin-panel/usuarios/<int:pk>/", AdminUserDetailView.as_view(), name="admin-user-detail"),
    path("admin-panel/usuarios/<int:pk>/toggle/", AdminUserToggleView.as_view(), name="admin-user-toggle"),
]
