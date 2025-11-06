from decimal import Decimal
from django.db.models import Q
from django.utils import timezone
from rest_framework import serializers

from .models import Category, Goal, Mission, MissionProgress, Transaction, TransactionLink, UserProfile, Friendship


class CategorySerializer(serializers.ModelSerializer):
    is_user_created = serializers.SerializerMethodField()
    
    class Meta:
        model = Category
        fields = ("id", "name", "type", "color", "group", "is_user_created")
    
    def get_is_user_created(self, obj):
        """Retorna True se a categoria foi criada pelo usuário (não é padrão)."""
        return obj.user is not None


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
            "id",  # Agora é UUID (primary key)
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
            "id",  # UUID é read-only (primary key)
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
        from decimal import Decimal
        
        attrs = super().validate(attrs)
        instance = getattr(self, "instance", None)

        # Validar amount é positivo
        amount = attrs.get('amount', getattr(instance, 'amount', None))
        if amount is not None and amount <= 0:
            raise serializers.ValidationError({
                'amount': 'O valor deve ser maior que zero.'
            })
        
        # Validar amount não é absurdamente grande (proteção contra erros)
        max_amount = Decimal('999999999.99')  # ~1 bilhão
        if amount is not None and amount > max_amount:
            raise serializers.ValidationError({
                'amount': f'Valor muito alto. Máximo permitido: R$ {max_amount:,.2f}'
            })

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
            # Validar recurrence_value não é absurdo
            if recurrence_value > 365:
                raise serializers.ValidationError({
                    'recurrence_value': 'Valor de recorrência muito alto.'
                })
        else:
            attrs["recurrence_value"] = None
            attrs["recurrence_unit"] = None
            attrs["recurrence_end_date"] = None
            if "is_recurring" in attrs:
                attrs["is_recurring"] = False
        
        # Validar data não está muito no futuro (opcional, mas pode ajudar)
        from django.utils import timezone
        from datetime import timedelta
        
        date = attrs.get('date', getattr(instance, 'date', None))
        if date:
            max_future_date = timezone.now().date() + timedelta(days=365)
            if date > max_future_date:
                raise serializers.ValidationError({
                    'date': 'Data não pode estar mais de 1 ano no futuro.'
                })

        return attrs


class GoalSerializer(serializers.ModelSerializer):
    progress_percentage = serializers.FloatField(read_only=True)
    category_name = serializers.CharField(source='target_category.name', read_only=True, allow_null=True)
    tracked_category_ids = serializers.PrimaryKeyRelatedField(
        many=True,
        queryset=Category.objects.all(),
        source='tracked_categories',
        required=False,
        allow_null=True,
        write_only=True
    )
    tracked_categories_data = serializers.SerializerMethodField(read_only=True)
    
    class Meta:
        model = Goal
        fields = (
            "id",  # Agora é UUID (primary key)
            "title",
            "description",
            "target_amount",
            "current_amount",
            "initial_amount",
            "deadline",
            "goal_type",
            "target_category",
            "category_name",
            "tracked_category_ids",
            "tracked_categories_data",
            "auto_update",
            "tracking_period",
            "is_reduction_goal",
            "progress_percentage",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")  # UUID é read-only (primary key)
    
    def get_tracked_categories_data(self, obj):
        """Retorna dados das categorias monitoradas."""
        return [
            {
                'id': cat.id,
                'name': cat.name,
                'color': cat.color,
                'type': cat.type,
                'group': cat.group,
            }
            for cat in obj.tracked_categories.all()
        ]

    def create(self, validated_data):
        tracked_categories = validated_data.pop('tracked_categories', [])
        validated_data["user"] = self.context["request"].user
        goal = super().create(validated_data)
        
        # Adicionar categorias monitoradas
        if tracked_categories:
            goal.tracked_categories.set(tracked_categories)
        
        return goal
    
    def update(self, instance, validated_data):
        tracked_categories = validated_data.pop('tracked_categories', None)
        goal = super().update(instance, validated_data)
        
        # Atualizar categorias monitoradas se fornecidas
        if tracked_categories is not None:
            goal.tracked_categories.set(tracked_categories)
        
        return goal
    
    def validate(self, attrs):
        """Valida que metas por categoria têm uma categoria vinculada."""
        goal_type = attrs.get('goal_type', Goal.GoalType.CUSTOM)
        target_category = attrs.get('target_category')
        tracked_categories = attrs.get('tracked_categories', [])
        
        # Metas de categoria EXPENSE/INCOME precisam ter uma categoria vinculada
        if goal_type in [Goal.GoalType.CATEGORY_EXPENSE, Goal.GoalType.CATEGORY_INCOME]:
            if not target_category:
                raise serializers.ValidationError({
                    'target_category': 'Metas por categoria precisam de uma categoria vinculada.'
                })
        
        # Validar que as categorias pertencem ao usuário ou são globais
        user = self.context['request'].user
        
        if target_category:
            if target_category.user and target_category.user != user:
                raise serializers.ValidationError({
                    'target_category': 'Você não pode usar uma categoria de outro usuário.'
                })
        
        for cat in tracked_categories:
            if cat.user and cat.user != user:
                raise serializers.ValidationError({
                    'tracked_category_ids': f'A categoria "{cat.name}" não pertence a você.'
                })
        
        # Validar current_amount em updates
        if self.instance:  # Só valida em updates
            current_amount = attrs.get('current_amount')
            if current_amount is not None:
                # Apenas metas CUSTOM ou metas sem auto_update podem ter current_amount editado
                goal_type = self.instance.goal_type
                auto_update = self.instance.auto_update
                
                # Bloqueia se não for CUSTOM E tiver auto_update ativo
                if goal_type != Goal.GoalType.CUSTOM and auto_update:
                    raise serializers.ValidationError({
                        'current_amount': 'Apenas metas personalizadas ou metas sem atualização automática podem ter o valor atual editado manualmente.'
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
    debt_payments = serializers.DecimalField(max_digits=12, decimal_places=2)


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
            "is_first_access",
        )
        read_only_fields = ("level", "experience_points", "next_level_threshold", "is_first_access")


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
    
    # Campos write-only para criação (agora apenas UUID)
    source_uuid = serializers.UUIDField(write_only=True, required=True)
    target_uuid = serializers.UUIDField(write_only=True, required=True)
    
    # Campos calculados
    source_description = serializers.SerializerMethodField()
    target_description = serializers.SerializerMethodField()
    formatted_amount = serializers.SerializerMethodField()
    
    class Meta:
        model = TransactionLink
        fields = (
            'id',  # Agora é UUID (primary key)
            'source_transaction',
            'target_transaction',
            'source_uuid',  # Aceita UUID (write-only)
            'target_uuid',  # Aceita UUID (write-only)
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
            'id',  # UUID é read-only (primary key)
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
        """Validações customizadas usando UUIDs."""
        request = self.context.get('request')
        if not request:
            raise serializers.ValidationError("Request context is required.")
        
        user = request.user
        
        source_uuid = attrs.get('source_uuid')
        target_uuid = attrs.get('target_uuid')
        linked_amount = attrs.get('linked_amount')
        
        # Validar que source existe e pertence ao usuário
        try:
            source = Transaction.objects.get(id=source_uuid, user=user)
        except Transaction.DoesNotExist:
            raise serializers.ValidationError({"source_uuid": "Transação de origem não encontrada."})
        
        # Validar que target existe e pertence ao usuário
        try:
            target = Transaction.objects.get(id=target_uuid, user=user)
        except Transaction.DoesNotExist:
            raise serializers.ValidationError({"target_uuid": "Transação de destino não encontrada."})
        
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
        
        # Adicionar UUIDs ao attrs para uso no create()
        attrs['source_transaction_uuid'] = source.id
        attrs['target_transaction_uuid'] = target.id
        
        return attrs
    
    def create(self, validated_data):
        """Criar vinculação usando UUIDs."""
        from .services import invalidate_indicators_cache
        
        # Remover campos write-only temporários (não são campos do modelo)
        validated_data.pop('source_uuid', None)
        validated_data.pop('target_uuid', None)
        
        # source_transaction_uuid e target_transaction_uuid já estão em validated_data
        # (foram adicionados pelo validate())
        
        # Adicionar usuário
        request = self.context.get('request')
        validated_data['user'] = request.user
        
        # Criar link com UUIDs
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


class FriendshipSerializer(serializers.ModelSerializer):
    """Serializer para relacionamentos de amizade."""
    user_info = serializers.SerializerMethodField()
    friend_info = serializers.SerializerMethodField()
    
    class Meta:
        model = Friendship
        fields = (
            'id',  # Agora é UUID (primary key)
            'user',
            'friend',
            'user_info',
            'friend_info',
            'status',
            'created_at',
            'accepted_at',
        )
        read_only_fields = ('id', 'user', 'status', 'created_at', 'accepted_at')  # UUID é read-only (primary key)
    
    def get_user_info(self, obj):
        """Retorna informações básicas do usuário que enviou."""
        from django.contrib.auth import get_user_model
        User = get_user_model()
        
        user = obj.user
        try:
            profile = UserProfile.objects.get(user=user)
        except UserProfile.DoesNotExist:
            profile = None
        
        return {
            'id': user.id,
            'username': user.username,
            'name': getattr(user, 'name', user.username),
            'email': user.email,
            'level': profile.level if profile else 1,
            'xp': profile.experience_points if profile else 0,
        }
    
    def get_friend_info(self, obj):
        """Retorna informações básicas do amigo."""
        friend = obj.friend
        try:
            profile = UserProfile.objects.get(user=friend)
        except UserProfile.DoesNotExist:
            profile = None
        
        return {
            'id': friend.id,
            'username': friend.username,
            'name': getattr(friend, 'name', friend.username),
            'email': friend.email,
            'level': profile.level if profile else 1,
            'xp': profile.experience_points if profile else 0,
        }


class FriendRequestSerializer(serializers.Serializer):
    """Serializer para enviar solicitação de amizade."""
    friend_id = serializers.IntegerField()
    
    def validate_friend_id(self, value):
        """Valida se o usuário existe e não é o próprio usuário."""
        from django.contrib.auth import get_user_model
        User = get_user_model()
        
        request = self.context.get('request')
        if not request or not request.user:
            raise serializers.ValidationError("Usuário não autenticado.")
        
        if value == request.user.id:
            raise serializers.ValidationError("Você não pode enviar solicitação para si mesmo.")
        
        try:
            User.objects.get(id=value)
        except User.DoesNotExist:
            raise serializers.ValidationError("Usuário não encontrado.")
        
        return value


class UserSearchSerializer(serializers.Serializer):
    """Serializer para busca de usuários."""
    id = serializers.IntegerField()
    username = serializers.CharField()
    name = serializers.CharField()
    email = serializers.EmailField()
    level = serializers.IntegerField()
    xp = serializers.IntegerField()
    is_friend = serializers.BooleanField()
    has_pending_request = serializers.BooleanField()


class LeaderboardEntrySerializer(serializers.Serializer):
    """Serializer para entrada no ranking."""
    rank = serializers.IntegerField()
    user_id = serializers.IntegerField()
    username = serializers.CharField()
    name = serializers.CharField()
    level = serializers.IntegerField()
    xp = serializers.IntegerField()
    is_current_user = serializers.BooleanField()
