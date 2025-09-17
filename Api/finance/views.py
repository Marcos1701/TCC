from django.db.models import Q
from rest_framework import mixins, permissions, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Category, Goal, Mission, MissionProgress, Transaction
from .serializers import (
    CategorySerializer,
    DashboardSummarySerializer,
    GoalSerializer,
    MissionProgressSerializer,
    MissionSerializer,
    TransactionSerializer,
)


class CategoryViewSet(viewsets.ModelViewSet):
    serializer_class = CategorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return Category.objects.filter(Q(user=user) | Q(user__isnull=True))

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class TransactionViewSet(viewsets.ModelViewSet):
    serializer_class = TransactionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Transaction.objects.filter(user=self.request.user)


class GoalViewSet(viewsets.ModelViewSet):
    serializer_class = GoalSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Goal.objects.filter(user=self.request.user)


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


class DashboardViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def list(self, request, *args, **kwargs):
        transactions = Transaction.objects.filter(user=request.user)
        data = DashboardSummarySerializer.from_transactions(transactions)
        serializer = DashboardSummarySerializer(data)
        return Response(serializer.data)

    @action(detail=False, methods=["get"], url_path="missions")
    def missions_summary(self, request):
        progress_qs = MissionProgress.objects.filter(user=request.user).select_related("mission")
        serializer = MissionProgressSerializer(progress_qs, many=True)
        return Response(serializer.data)
