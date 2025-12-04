from django.conf import settings
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path

from finance.authentication import EmailTokenObtainPairView, CustomTokenRefreshView


def health_check(request):
    """
    Endpoint de health check para verificar se a API está funcionando.
    Usado pelo Docker/Kubernetes para verificar a saúde do container.
    """
    return JsonResponse({
        "status": "healthy",
        "service": "genapp-api",
        "version": "1.0.0"
    })


urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include("finance.urls")),
    path("api/token/", EmailTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("api/token/refresh/", CustomTokenRefreshView.as_view(), name="token_refresh"),
    path("api/health/", health_check, name="health_check"),
    path("health/", health_check, name="health_check_root"),  # Alias para compatibilidade
]

if settings.DEBUG:
    import debug_toolbar
    urlpatterns = [
        path("__debug__/", include(debug_toolbar.urls)),
    ] + urlpatterns
