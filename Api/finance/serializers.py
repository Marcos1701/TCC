from decimal import Decimal
from django.db.models import Q
from django.utils import timezone
from rest_framework import serializers

from .models import Category, Goal, Mission, MissionProgress, Transaction, UserProfile


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ("id", "name", "type", "color", "group")


class TransactionSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)
    category_id = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.none(), source="category", write_only=True, allow_null=True, required=False
    )
    # Campos calculados read-only
    recurrence_description = serializers.SerializerMethodField()
    days_since_created = serializers.SerializerMethodField()
    formatted_amount = serializers.SerializerMethodField()

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
            "is_recurring",
            "recurrence_value",
            "recurrence_unit",
            "recurrence_end_date",
            "recurrence_description",
            "days_since_created",
            "formatted_amount",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "recurrence_description",
            "days_since_created",
            "formatted_amount",
            "created_at",
            "updated_at",
        )

    def get_recurrence_description(self, obj):
        """Retorna descrição legível da recorrência."""
        if not obj.is_recurring or not obj.recurrence_value or not obj.recurrence_unit:
            return None
        
        value = obj.recurrence_value
        unit_map = {
            'DAYS': ('dia', 'dias'),
            'WEEKS': ('semana', 'semanas'),
            'MONTHS': ('mês', 'meses'),
        }
        
        singular, plural = unit_map.get(obj.recurrence_unit, ('período', 'períodos'))
        unit_text = singular if value == 1 else plural
        
        desc = f"A cada {value} {unit_text}"
        if obj.recurrence_end_date:
            from datetime import datetime
            end_date = obj.recurrence_end_date.strftime('%d/%m/%Y')
            desc += f" até {end_date}"
        
        return desc
    
    def get_days_since_created(self, obj):
        """Retorna quantos dias desde a criação."""
        from django.utils import timezone
        delta = timezone.now() - obj.created_at
        return delta.days
    
    def get_formatted_amount(self, obj):
        """Retorna valor formatado em BRL."""
        return f"R$ {obj.amount:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.')

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

    def validate(self, attrs):
        attrs = super().validate(attrs)
        instance = getattr(self, "instance", None)

        is_recurring = attrs.get("is_recurring")
        if is_recurring is None and instance is not None:
            is_recurring = instance.is_recurring

        recurrence_value = attrs.get(
            "recurrence_value",
            getattr(instance, "recurrence_value", None),
        )
        recurrence_unit = attrs.get(
            "recurrence_unit",
            getattr(instance, "recurrence_unit", None),
        )

        if is_recurring:
            if not recurrence_value or recurrence_value <= 0 or not recurrence_unit:
                raise serializers.ValidationError(
                    "Informe a frequência para transações recorrentes.",
                )
        else:
            attrs["recurrence_value"] = None
            attrs["recurrence_unit"] = None
            attrs["recurrence_end_date"] = None
            if "is_recurring" in attrs:
                attrs["is_recurring"] = False

        return attrs


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
            "mission_type",
            "priority",
            "target_tps",
            "target_rdr",
            "min_ili",
            "max_ili",
            "min_transactions",
            "duration_days",
            "is_active",
        )


class MissionProgressSerializer(serializers.ModelSerializer):
    mission = MissionSerializer(read_only=True)
    mission_id = serializers.PrimaryKeyRelatedField(
        queryset=Mission.objects.all(), source="mission", write_only=True
    )
    # Campos calculados
    days_remaining = serializers.SerializerMethodField()
    progress_percentage = serializers.SerializerMethodField()
    current_vs_initial = serializers.SerializerMethodField()

    class Meta:
        model = MissionProgress
        fields = (
            "id",
            "mission",
            "mission_id",
            "status",
            "progress",
            "initial_tps",
            "initial_rdr",
            "initial_ili",
            "initial_transaction_count",
            "started_at",
            "completed_at",
            "updated_at",
            "days_remaining",
            "progress_percentage",
            "current_vs_initial",
        )
        read_only_fields = (
            "initial_tps",
            "initial_rdr",
            "initial_ili",
            "initial_transaction_count",
            "days_remaining",
            "progress_percentage",
            "current_vs_initial",
        )

    def get_days_remaining(self, obj):
        """Retorna dias restantes até o prazo ou None se não tiver prazo."""
        if not obj.started_at or not obj.mission.duration_days:
            return None
        
        from django.utils import timezone
        deadline = obj.started_at + timezone.timedelta(days=obj.mission.duration_days)
        delta = deadline - timezone.now()
        return max(0, delta.days)
    
    def get_progress_percentage(self, obj):
        """Retorna progresso formatado como string."""
        return f"{float(obj.progress):.1f}%"
    
    def get_current_vs_initial(self, obj):
        """Retorna comparação dos indicadores atuais vs iniciais."""
        from .services import calculate_summary
        
        # Pegar indicadores atuais
        summary = calculate_summary(obj.user)
        
        result = {}
        
        if obj.initial_tps is not None:
            result['tps'] = {
                'initial': float(obj.initial_tps),
                'current': float(summary.get('tps', 0)),
                'change': float(summary.get('tps', 0)) - float(obj.initial_tps),
            }
        
        if obj.initial_rdr is not None:
            result['rdr'] = {
                'initial': float(obj.initial_rdr),
                'current': float(summary.get('rdr', 0)),
                'change': float(obj.initial_rdr) - float(summary.get('rdr', 0)),  # Invertido: redução é positivo
            }
        
        if obj.initial_ili is not None:
            result['ili'] = {
                'initial': float(obj.initial_ili),
                'current': float(summary.get('ili', 0)),
                'change': float(summary.get('ili', 0)) - float(obj.initial_ili),
            }
        
        return result if result else None

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
    ili = serializers.DecimalField(max_digits=6, decimal_places=2)
    total_income = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_expense = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_debt = serializers.DecimalField(max_digits=12, decimal_places=2)


class CategoryBreakdownSerializer(serializers.Serializer):
    name = serializers.CharField()
    total = serializers.DecimalField(max_digits=12, decimal_places=2)
    group = serializers.CharField()


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
    target = serializers.DecimalField(max_digits=6, decimal_places=2)


class UserProfileSerializer(serializers.ModelSerializer):
    next_level_threshold = serializers.IntegerField(read_only=True)

    class Meta:
        model = UserProfile
        fields = (
            "level",
            "experience_points",
            "next_level_threshold",
            "target_tps",
            "target_rdr",
            "target_ili",
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
