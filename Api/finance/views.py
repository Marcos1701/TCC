from django.contrib.auth import get_user_model
from django.db.models import Q
from rest_framework import mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Category, Goal, Mission, MissionProgress, Transaction
from .serializers import (
    CategorySerializer,
    DashboardSerializer,
    GoalSerializer,
    MissionProgressSerializer,
    MissionSerializer,
    TransactionSerializer,
    UserProfileSerializer,
)
from .services import (
    apply_mission_reward,
    calculate_summary,
    cashflow_series,
    category_breakdown,
    profile_snapshot,
    recommend_missions,
)

User = get_user_model()


class CategoryViewSet(viewsets.ModelViewSet):
    serializer_class = CategorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = Category.objects.filter(Q(user=user) | Q(user__isnull=True))
        category_type = self.request.query_params.get("type")
        if category_type:
            qs = qs.filter(type=category_type)
        return qs.order_by("name")

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class TransactionViewSet(viewsets.ModelViewSet):
    serializer_class = TransactionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = Transaction.objects.filter(user=self.request.user).select_related("category")
        tx_type = self.request.query_params.get("type")
        if tx_type:
            qs = qs.filter(type=tx_type)
        return qs.order_by("-date", "-created_at")


class GoalViewSet(viewsets.ModelViewSet):
    serializer_class = GoalSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Goal.objects.filter(user=self.request.user).order_by("deadline", "title")


class MissionViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = MissionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Mission.objects.filter(is_active=True)


class MissionProgressViewSet(viewsets.ModelViewSet):
    serializer_class = MissionProgressSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return MissionProgress.objects.filter(user=self.request.user).select_related("mission")

    def perform_create(self, serializer):
        progress = serializer.save()
        if progress.status == MissionProgress.Status.COMPLETED:
            apply_mission_reward(progress)

    def perform_update(self, serializer):
        previous = serializer.instance.status
        progress = serializer.save()
        if (
            previous != MissionProgress.Status.COMPLETED
            and progress.status == MissionProgress.Status.COMPLETED
        ):
            apply_mission_reward(progress)


class DashboardViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def list(self, request, *args, **kwargs):
        summary = calculate_summary(request.user)
        breakdown = category_breakdown(request.user)
        cashflow = cashflow_series(request.user)
        missions = (
            MissionProgress.objects.filter(user=request.user)
            .exclude(status=MissionProgress.Status.COMPLETED)
            .select_related("mission")
        )
        recommendations = recommend_missions(request.user, summary)
        serializer = DashboardSerializer(
            {
                "summary": summary,
                "categories": breakdown,
                "cashflow": cashflow,
                "active_missions": missions,
                "recommended_missions": list(recommendations),
                "profile": request.user.userprofile,
            },
            context={"request": request},
        )
        return Response(serializer.data)

    @action(detail=False, methods=["get"], url_path="missions")
    def missions_summary(self, request):
        progress_qs = MissionProgress.objects.filter(user=request.user).select_related("mission")
        serializer = MissionProgressSerializer(progress_qs, many=True)
        return Response(serializer.data)

class ProfileView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        data = {
            "user": {
                "id": request.user.id,
                "email": request.user.email,
                "name": request.user.get_full_name() or request.user.username,
            },
            "profile": UserProfileSerializer(request.user.userprofile).data,
            "snapshot": profile_snapshot(request.user),
        }
        return Response(data)

    def put(self, request):
        serializer = UserProfileSerializer(
            request.user.userprofile, data=request.data, partial=True
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        data = {
            "profile": serializer.data,
            "snapshot": profile_snapshot(request.user),
        }
        return Response(data)


class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        password = request.data.get("password")
        name = request.data.get("name", "").strip()

        if not email or not password:
            return Response(
                {"detail": "Email e senha são obrigatórios."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if User.objects.filter(email__iexact=email).exists():
            return Response(
                {"detail": "Já existe uma conta com esse email."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        username = email.split("@", 1)[0]
        user = User.objects.create_user(username=username, email=email, password=password)
        if name:
            parts = name.split(" ")
            user.first_name = parts[0]
            if len(parts) > 1:
                user.last_name = " ".join(parts[1:])
            user.save(update_fields=["first_name", "last_name"])

        refresh = RefreshToken.for_user(user)
        tokens = {"access": str(refresh.access_token), "refresh": str(refresh)}

        return Response({"tokens": tokens}, status=status.HTTP_201_CREATED)
