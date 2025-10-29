from __future__ import annotations

from django.contrib.auth import get_user_model
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.views import TokenObtainPairView


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
            except user_model.DoesNotExist as exc:  # pragma: no cover - feedback uniforme
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
    serializer_class = EmailTokenObtainPairSerializer
