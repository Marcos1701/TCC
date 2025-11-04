from decimal import Decimal
from django.db.models import Q
from django.utils import timezone
from rest_framework import serializers

from .models import Category, Goal, Mission, MissionProgress, Transaction, TransactionLink, UserProfile


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
    
    # NOVOS CAMPOS para vinculação
    linked_amount = serializers.SerializerMethodField()
    available_amount = serializers.SerializerMethodField()
    link_percentage = serializers.SerializerMethodField()
    outgoing_links_count = serializers.SerializerMethodField()
    incoming_links_count = serializers.SerializerMethodField()

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
            # Novos campos
            "linked_amount",
            "available_amount",
            "link_percentage",
            "outgoing_links_count",
            "incoming_links_count",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "recurrence_description",
            "days_since_created",
            "formatted_amount",
            "linked_amount",
            "available_amount",
            "link_percentage",
            "outgoing_links_count",
            "incoming_links_count",
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
    
    def get_linked_amount(self, obj):
        """Retorna valor total vinculado."""
        return float(obj.linked_amount)
    
    def get_available_amount(self, obj):
        """Retorna valor disponível (não vinculado)."""
        return float(obj.available_amount)
    
    def get_link_percentage(self, obj):
        """Retorna percentual vinculado."""
        return float(obj.link_percentage)
    
    def get_outgoing_links_count(self, obj):
        """Retorna número de links de saída."""
        return obj.outgoing_links.count()
    
    def get_incoming_links_count(self, obj):
        """Retorna número de links de entrada."""
        return obj.incoming_links.count()

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
    progress_percentage = serializers.FloatField(read_only=True)
    category_name = serializers.CharField(source='target_category.name', read_only=True, allow_null=True)
    
    class Meta:
        model = Goal
        fields = (
            "id",
            "title",
            "description",
            "target_amount",
            "current_amount",
            "deadline",
            "goal_type",
            "target_category",
            "category_name",
            "auto_update",
            "tracking_period",
            "is_reduction_goal",
            "progress_percentage",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("current_amount", "created_at", "updated_at")

    def create(self, validated_data):
        validated_data["user"] = self.context["request"].user
        return super().create(validated_data)
    
    def validate(self, attrs):
        """Valida que metas por categoria têm uma categoria vinculada."""
        goal_type = attrs.get('goal_type', Goal.GoalType.CUSTOM)
        target_category = attrs.get('target_category')
        
        # Metas de categoria precisam ter uma categoria vinculada
        if goal_type in [Goal.GoalType.CATEGORY_EXPENSE, Goal.GoalType.CATEGORY_INCOME]:
            if not target_category:
                raise serializers.ValidationError({
                    'target_category': 'Metas por categoria precisam de uma categoria vinculada.'
                })
        
        # Validar que a categoria pertence ao usuário ou é global
        if target_category:
            user = self.context['request'].user
            if target_category.user and target_category.user != user:
                raise serializers.ValidationError({
                    'target_category': 'Você não pode usar uma categoria de outro usuário.'
                })
        
        return attrs


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


class TransactionLinkSerializer(serializers.ModelSerializer):
    """Serializer para TransactionLink."""
    
    # Campos read-only nested
    source_transaction = TransactionSerializer(read_only=True)
    target_transaction = TransactionSerializer(read_only=True)
    
    # Campos write-only para criação
    source_id = serializers.IntegerField(write_only=True)
    target_id = serializers.IntegerField(write_only=True)
    
    # Campos calculados
    source_description = serializers.SerializerMethodField()
    target_description = serializers.SerializerMethodField()
    formatted_amount = serializers.SerializerMethodField()
    
    class Meta:
        model = TransactionLink
        fields = (
            'id',
            'source_transaction',
            'target_transaction',
            'source_id',
            'target_id',
            'linked_amount',
            'link_type',
            'description',
            'is_recurring',
            'created_at',
            'updated_at',
            'source_description',
            'target_description',
            'formatted_amount',
        )
        read_only_fields = (
            'created_at',
            'updated_at',
            'source_description',
            'target_description',
            'formatted_amount',
        )
    
    def get_source_description(self, obj):
        return obj.source_transaction.description if obj.source_transaction else None
    
    def get_target_description(self, obj):
        return obj.target_transaction.description if obj.target_transaction else None
    
    def get_formatted_amount(self, obj):
        return f"R$ {obj.linked_amount:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.')
    
    def validate(self, attrs):
        """Validações customizadas."""
        request = self.context.get('request')
        if not request:
            raise serializers.ValidationError("Request context is required.")
        
        user = request.user
        source_id = attrs.get('source_id')
        target_id = attrs.get('target_id')
        linked_amount = attrs.get('linked_amount')
        
        # Validar que source existe e pertence ao usuário
        try:
            source = Transaction.objects.get(id=source_id, user=user)
        except Transaction.DoesNotExist:
            raise serializers.ValidationError({"source_id": "Transação de origem não encontrada."})
        
        # Validar que target existe e pertence ao usuário
        try:
            target = Transaction.objects.get(id=target_id, user=user)
        except Transaction.DoesNotExist:
            raise serializers.ValidationError({"target_id": "Transação de destino não encontrada."})
        
        # Validar que linked_amount não excede disponível na source
        if linked_amount > source.available_amount:
            raise serializers.ValidationError({
                "linked_amount": f"Valor excede o disponível na receita (R$ {source.available_amount})"
            })
        
        # Validar que linked_amount não excede devido na target (se for dívida)
        if target.category and target.category.type == 'DEBT':
            if linked_amount > target.available_amount:
                raise serializers.ValidationError({
                    "linked_amount": f"Valor excede o devido na dívida (R$ {target.available_amount})"
                })
        
        # Adicionar transações ao attrs para uso no create()
        attrs['source_transaction'] = source
        attrs['target_transaction'] = target
        
        return attrs
    
    def create(self, validated_data):
        """Criar vinculação."""
        from .services import invalidate_indicators_cache
        
        # Remover campos write-only
        validated_data.pop('source_id', None)
        validated_data.pop('target_id', None)
        
        # Adicionar usuário
        request = self.context.get('request')
        validated_data['user'] = request.user
        
        # Criar link
        link = TransactionLink.objects.create(**validated_data)
        
        # Invalidar cache de indicadores
        invalidate_indicators_cache(request.user)
        
        return link


class TransactionLinkSummarySerializer(serializers.Serializer):
    """Serializer para resumo de vinculações por transação."""
    transaction_id = serializers.IntegerField()
    transaction_description = serializers.CharField()
    transaction_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    linked_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    available_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    link_percentage = serializers.DecimalField(max_digits=5, decimal_places=2)
