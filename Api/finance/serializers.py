from decimal import Decimal
from django.db.models import Q
from django.utils import timezone
from rest_framework import serializers

from .models import Category, Goal, Mission, MissionProgress, Transaction, UserProfile


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ("id", "name", "type", "color")


class TransactionSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)
    category_id = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.none(), source="category", write_only=True, allow_null=True, required=False
    )

    class Meta:
        model = Transaction
        fields = (
            "id",
            "type",
            "description",
            "amount",
            "date",
            "category",
            "category_id",
        )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request and request.user.is_authenticated:
            self.fields["category_id"].queryset = Category.objects.filter(
                Q(user=request.user) | Q(user__isnull=True)
            )

    def create(self, validated_data):
        user = self.context["request"].user
        validated_data["user"] = user
        return super().create(validated_data)


class GoalSerializer(serializers.ModelSerializer):
    class Meta:
        model = Goal
        fields = (
            "id",
            "title",
            "description",
            "target_amount",
            "current_amount",
            "deadline",
        )

    def create(self, validated_data):
        validated_data["user"] = self.context["request"].user
        return super().create(validated_data)


class MissionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Mission
        fields = (
            "id",
            "title",
            "description",
            "reward_points",
            "difficulty",
            "target_tps",
            "target_rdr",
            "duration_days",
            "is_active",
        )


class MissionProgressSerializer(serializers.ModelSerializer):
    mission = MissionSerializer(read_only=True)
    mission_id = serializers.PrimaryKeyRelatedField(
        queryset=Mission.objects.all(), source="mission", write_only=True
    )

    class Meta:
        model = MissionProgress
        fields = (
            "id",
            "mission",
            "mission_id",
            "status",
            "progress",
            "started_at",
            "completed_at",
            "updated_at",
        )

    def create(self, validated_data):
        validated_data["user"] = self.context["request"].user
        validated_data.setdefault("status", MissionProgress.Status.ACTIVE)
        validated_data.setdefault("started_at", timezone.now())
        return super().create(validated_data)

    def update(self, instance, validated_data):
        status = validated_data.get("status", instance.status)
        if status == MissionProgress.Status.ACTIVE and instance.started_at is None:
            validated_data.setdefault("started_at", timezone.now())
        if status == MissionProgress.Status.COMPLETED:
            validated_data.setdefault("completed_at", timezone.now())
        return super().update(instance, validated_data)

class DashboardSummarySerializer(serializers.Serializer):
    tps = serializers.DecimalField(max_digits=6, decimal_places=2)
    rdr = serializers.DecimalField(max_digits=6, decimal_places=2)
    total_income = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_expense = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_debt = serializers.DecimalField(max_digits=12, decimal_places=2)

    @staticmethod
    def from_transactions(transactions):
        totals = {
            "INCOME": Decimal("0"),
            "EXPENSE": Decimal("0"),
            "DEBT_PAYMENT": Decimal("0"),
        }
        for tx in transactions:
            totals[tx.type] += tx.amount

        total_income = totals["INCOME"]
        total_expense = totals["EXPENSE"]
        total_debt = totals["DEBT_PAYMENT"]

        tps = Decimal("0")
        rdr = Decimal("0")
        if total_income > 0:
            tps = ((total_income - total_expense) / total_income) * 100
            rdr = ((total_debt or total_expense) / total_income) * 100

        return {
            "tps": tps.quantize(Decimal("0.01")) if total_income > 0 else Decimal("0.00"),
            "rdr": rdr.quantize(Decimal("0.01")) if total_income > 0 else Decimal("0.00"),
            "total_income": total_income.quantize(Decimal("0.01")),
            "total_expense": total_expense.quantize(Decimal("0.01")),
            "total_debt": total_debt.quantize(Decimal("0.01")),
        }
class CategoryBreakdownSerializer(serializers.Serializer):
    name = serializers.CharField()
    total = serializers.DecimalField(max_digits=12, decimal_places=2)


class CashflowPointSerializer(serializers.Serializer):
    month = serializers.CharField()
    income = serializers.DecimalField(max_digits=12, decimal_places=2)
    expense = serializers.DecimalField(max_digits=12, decimal_places=2)
    debt = serializers.DecimalField(max_digits=12, decimal_places=2)
    tps = serializers.DecimalField(max_digits=6, decimal_places=2)
    rdr = serializers.DecimalField(max_digits=6, decimal_places=2)


class IndicatorInsightSerializer(serializers.Serializer):
    severity = serializers.CharField()
    title = serializers.CharField()
    message = serializers.CharField()
    value = serializers.DecimalField(max_digits=6, decimal_places=2)
    target = serializers.IntegerField()


class UserProfileSerializer(serializers.ModelSerializer):
    next_level_threshold = serializers.IntegerField(read_only=True, source="next_level_threshold")

    class Meta:
        model = UserProfile
        fields = (
            "level",
            "experience_points",
            "next_level_threshold",
            "target_tps",
            "target_rdr",
        )
        read_only_fields = ("level", "experience_points", "next_level_threshold")


class DashboardSerializer(serializers.Serializer):
    summary = DashboardSummarySerializer()
    categories = serializers.DictField(child=CategoryBreakdownSerializer(many=True))
    cashflow = CashflowPointSerializer(many=True)
    insights = serializers.DictField(child=IndicatorInsightSerializer())
    active_missions = MissionProgressSerializer(many=True)
    recommended_missions = MissionSerializer(many=True)
    profile = UserProfileSerializer()
