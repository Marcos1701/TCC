from __future__ import annotations

from django.contrib.auth import get_user_model
from rest_framework import permissions
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView


class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Serializer que permite autenticar usando email ou username."""

    default_error_messages = {
        **TokenObtainPairSerializer.default_error_messages,
        "no_active_account": "Credenciais inválidas.",
    }

    def validate(self, attrs):
        identifier = (attrs.get("username") or attrs.get("email") or "").strip()
        if identifier and "@" in identifier:
            user_model = get_user_model()
            try:
                user = user_model.objects.only(user_model.USERNAME_FIELD).get(email__iexact=identifier)
            except user_model.DoesNotExist as exc:
                raise AuthenticationFailed("Credenciais inválidas.", code="authentication") from exc
            attrs["username"] = getattr(user, user_model.USERNAME_FIELD)
        else:
            attrs["username"] = identifier

        data = super().validate(attrs)
        data["user"] = {
            "id": self.user.id,
            "email": self.user.email,
            "name": self.user.get_full_name() or self.user.get_username(),
        }
        return data


class EmailTokenObtainPairView(TokenObtainPairView):
    """View de autenticação que permite login com email ou username."""
    serializer_class = EmailTokenObtainPairSerializer
    permission_classes = [permissions.AllowAny]
    authentication_classes = []
    throttle_classes = []


class CustomTokenRefreshView(TokenRefreshView):
    """View para refresh de token."""
    permission_classes = [permissions.AllowAny]
    authentication_classes = []
    throttle_classes = []
