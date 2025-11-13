from django.conf import settings
from django.contrib import admin
from django.urls import include, path

from finance.authentication import EmailTokenObtainPairView, CustomTokenRefreshView

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include("finance.urls")),
    path("api/token/", EmailTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("api/token/refresh/", CustomTokenRefreshView.as_view(), name="token_refresh"),
]

# Django Debug Toolbar URLs (apenas em DEBUG mode)
if settings.DEBUG:
    import debug_toolbar
    urlpatterns = [
        path("__debug__/", include(debug_toolbar.urls)),
    ] + urlpatterns
