from decimal import Decimal
from django.db.models import Q
from django.utils import timezone
from rest_framework import serializers

from .models import (
    Achievement,
    Category,
    Friendship,
    Goal,
    Mission,
    MissionProgress,
    MissionProgressSnapshot,
    Transaction,
    TransactionLink,
    UserAchievement,
    UserDailySnapshot,
    UserMonthlySnapshot,
    UserProfile,
)


class CategorySerializer(serializers.ModelSerializer):
    is_user_created = serializers.SerializerMethodField()
    
    class Meta:
        model = Category
        fields = ("id", "name", "type", "color", "group", "is_system_default", "is_user_created")
        read_only_fields = ("id", "is_user_created")
    
    def get_is_user_created(self, obj):
        """
        Retorna True se a categoria foi criada pelo usuário (não é padrão do sistema).
        Categoria é considerada do usuário apenas se:
        - Tem user associado (user is not None) E
        - NÃO é categoria padrão do sistema (is_system_default=False)
        """
        try:
            return obj.user is not None and not obj.is_system_default
        except Category.user.RelatedObjectDoesNotExist:
            return False
    
    def validate_color(self, value):
        """Valida que a cor está no formato hexadecimal correto."""
        import re
        if not value:
            return '#808080'  # Cor padrão (cinza)
        
        # Permitir tanto #RGB quanto #RRGGBB
        if not re.match(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$', value):
            raise serializers.ValidationError(
                'Cor deve estar no formato hexadecimal (#RRGGBB ou #RGB). Exemplo: #FF5733'
            )
        
        return value.upper()  # Padronizar para maiúsculas
    
    def validate_name(self, value):
        """Valida que o nome não está vazio e tem tamanho apropriado."""
        if not value or not value.strip():
            raise serializers.ValidationError("O nome da categoria não pode estar vazio.")
        if len(value) > 100:
            raise serializers.ValidationError("O nome não pode ter mais de 100 caracteres.")
        return value.strip()


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
        """
        Retorna número de links de saída.
        Otimizado: Usa annotation do queryset se disponível, senão faz query.
        """
        if hasattr(obj, 'outgoing_links_count_annotated'):
            return obj.outgoing_links_count_annotated
        return obj.outgoing_links.count()
    
    def get_incoming_links_count(self, obj):
        """
        Retorna número de links de entrada.
        Otimizado: Usa annotation do queryset se disponível, senão faz query.
        """
        if hasattr(obj, 'incoming_links_count_annotated'):
            return obj.incoming_links_count_annotated
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
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request and request.user.is_authenticated:
            # Filtra categorias do usuário + categorias globais (sistema)
            category_queryset = Category.objects.filter(
                Q(user=request.user) | Q(user__isnull=True)
            )
            # Aplica o queryset filtrado aos campos de categoria
            self.fields["tracked_category_ids"].queryset = category_queryset
            if "target_category" in self.fields:
                self.fields["target_category"].queryset = category_queryset
    
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
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"[GOAL SERIALIZER] Validating attrs: {attrs}")
        
        goal_type = attrs.get('goal_type', Goal.GoalType.CUSTOM)
        target_category = attrs.get('target_category')
        tracked_categories = attrs.get('tracked_categories', [])
        
        logger.info(f"[GOAL SERIALIZER] goal_type={goal_type}, target_category={target_category}, tracked_categories={len(tracked_categories)}")
        
        # Metas de categoria EXPENSE/INCOME precisam ter uma categoria vinculada
        # Pode ser target_category OU tracked_categories
        if goal_type in [Goal.GoalType.CATEGORY_EXPENSE, Goal.GoalType.CATEGORY_INCOME]:
            if not target_category and not tracked_categories:
                logger.error(f"[GOAL SERIALIZER] Validation failed: goal_type={goal_type} requires target_category or tracked_categories")
                raise serializers.ValidationError({
                    'target_category': 'Metas por categoria precisam de pelo menos uma categoria vinculada (target_category ou tracked_categories).'
                })
        
        # Validar que as categorias pertencem ao usuário ou são globais
        user = self.context['request'].user
        
        if target_category:
            logger.info(f"[GOAL SERIALIZER] Validating target_category: user={target_category.user}, current_user={user}")
            if target_category.user and target_category.user != user:
                logger.error(f"[GOAL SERIALIZER] Validation failed: target_category belongs to different user")
                raise serializers.ValidationError({
                    'target_category': 'Você não pode usar uma categoria de outro usuário.'
                })
        
        for cat in tracked_categories:
            if cat.user and cat.user != user:
                logger.error(f"[GOAL SERIALIZER] Validation failed: tracked_category {cat.name} belongs to different user")
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
                    logger.error(f"[GOAL SERIALIZER] Validation failed: cannot edit current_amount with auto_update enabled")
                    raise serializers.ValidationError({
                        'current_amount': 'Apenas metas personalizadas ou metas sem atualização automática podem ter o valor atual editado manualmente.'
                    })
        
        logger.info(f"[GOAL SERIALIZER] Validation passed")
        return attrs


class MissionSerializer(serializers.ModelSerializer):
    # Campos calculados para melhor exibição no front
    type_display = serializers.CharField(source='get_mission_type_display', read_only=True)
    difficulty_display = serializers.CharField(source='get_difficulty_display', read_only=True)
    validation_type_display = serializers.CharField(source='get_validation_type_display', read_only=True)
    
    # Informações de origem da missão
    source = serializers.SerializerMethodField()
    
    # Informações contextuais
    target_info = serializers.SerializerMethodField()
    
    # Serializers aninhados para relações ManyToMany
    target_categories = CategorySerializer(many=True, read_only=True)
    target_category = CategorySerializer(read_only=True)
    
    class Meta:
        model = Mission
        fields = [
            "id",
            "title",
            "description",
            "reward_points",
            "difficulty",
            "difficulty_display",
            "mission_type",
            "type_display",
            "priority",
            "target_tps",
            "target_rdr",
            "min_ili",
            "max_ili",
            "min_transactions",
            "duration_days",
            "is_active",
            "validation_type",
            "validation_type_display",
            "requires_consecutive_days",
            "min_consecutive_days",
            "target_category",
            "target_reduction_percent",
            "category_spending_limit",
            "target_goal",
            "goal_progress_target",
            "savings_increase_amount",
            "requires_daily_action",
            "min_daily_actions",
            "impacts",
            "tips",
            "min_transaction_frequency",
            "transaction_type_filter",
            "target_categories",
            "requires_payment_tracking",
            "min_payments_count",
            "is_system_generated",
            "generation_context",
            "source",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]
    
    def get_source(self, obj):
        """Identifica a origem da missão (template ou IA)."""
        if obj.is_system_generated:
            return "system"  # Missões geradas pelo sistema
        elif obj.priority >= 90:
            return "system"  # Missões padrão do sistema
        elif obj.priority >= 5:
            return "template"  # Geradas por templates
        else:
            return "ai"  # Geradas por IA
    
    def get_target_info(self, obj):
        """Retorna informações consolidadas sobre os alvos da missão."""
        info = {
            'type': obj.mission_type,
            'validation_type': obj.validation_type,
            'targets': []
        }
        
        # Indicadores financeiros
        if obj.target_tps is not None:
            info['targets'].append({
                'metric': 'TPS',
                'label': 'Taxa de Poupança',
                'value': float(obj.target_tps),
                'unit': '%',
                'icon': '💰'
            })
        
        if obj.target_rdr is not None:
            info['targets'].append({
                'metric': 'RDR',
                'label': 'Despesas Recorrentes',
                'value': float(obj.target_rdr),
                'unit': '%',
                'icon': '📉'
            })
        
        if obj.min_ili is not None:
            info['targets'].append({
                'metric': 'ILI',
                'label': 'Reserva de Emergência',
                'value': float(obj.min_ili),
                'unit': 'meses',
                'icon': '🛡️'
            })
        
        # Transações mínimas (onboarding)
        if obj.min_transactions is not None:
            info['targets'].append({
                'metric': 'TRANSACTIONS',
                'label': 'Transações',
                'value': obj.min_transactions,
                'unit': 'registros',
                'icon': '📝'
            })
        
        # Categoria alvo
        if obj.target_category:
            info['targets'].append({
                'metric': 'CATEGORY',
                'label': obj.target_category.name,
                'category_id': obj.target_category.id,
                'icon': '📁'
            })
        
        # Categorias múltiplas
        if obj.target_categories.exists():
            info['targets'].append({
                'metric': 'CATEGORIES',
                'label': f'{obj.target_categories.count()} categorias',
                'count': obj.target_categories.count(),
                'icon': '📂'
            })
        
        # Meta alvo
        if obj.target_goal:
            info['targets'].append({
                'metric': 'GOAL',
                'label': obj.target_goal.title,
                'goal_id': obj.target_goal.id,
                'icon': '🎯'
            })
        
        # Metas múltiplas
        if obj.target_goals.exists():
            info['targets'].append({
                'metric': 'GOALS',
                'label': f'{obj.target_goals.count()} metas',
                'count': obj.target_goals.count(),
                'icon': '🎯'
            })
        
        # Frequência de transações
        if obj.min_transaction_frequency:
            info['targets'].append({
                'metric': 'FREQUENCY',
                'label': 'Transações por semana',
                'value': obj.min_transaction_frequency,
                'unit': 'por semana',
                'icon': '📊'
            })
        
        # Contagem de pagamentos
        if obj.min_payments_count:
            info['targets'].append({
                'metric': 'PAYMENTS',
                'label': 'Pagamentos',
                'value': obj.min_payments_count,
                'unit': 'pagamentos',
                'icon': '💳'
            })
        
        # Redução percentual
        if obj.target_reduction_percent:
            info['targets'].append({
                'metric': 'REDUCTION',
                'label': 'Redução de gastos',
                'value': float(obj.target_reduction_percent),
                'unit': '%',
                'icon': '📉'
            })
        
        # Limite de gastos
        if obj.category_spending_limit:
            info['targets'].append({
                'metric': 'LIMIT',
                'label': 'Limite de gastos',
                'value': float(obj.category_spending_limit),
                'unit': 'R$',
                'icon': '💰'
            })
        
        # Progresso de meta
        if obj.goal_progress_target:
            info['targets'].append({
                'metric': 'GOAL_PROGRESS',
                'label': 'Progresso de meta',
                'value': float(obj.goal_progress_target),
                'unit': '%',
                'icon': '📈'
            })
        
        return info
    
    def validate_title(self, value):
        """Valida que o título não está vazio e tem tamanho apropriado."""
        if not value or not value.strip():
            raise serializers.ValidationError("O título não pode estar vazio.")
        if len(value) > 150:
            raise serializers.ValidationError("O título não pode ter mais de 150 caracteres.")
        return value.strip()
    
    def validate_description(self, value):
        """Valida que a descrição não está vazia."""
        if not value or not value.strip():
            raise serializers.ValidationError("A descrição não pode estar vazia.")
        return value.strip()
    
    def validate_reward_points(self, value):
        """Valida que os pontos de recompensa estão em um range válido."""
        if value < 10:
            raise serializers.ValidationError("A recompensa deve ser no mínimo 10 XP.")
        if value > 1000:
            raise serializers.ValidationError("A recompensa não pode exceder 1000 XP.")
        return value
    
    def validate_duration_days(self, value):
        """Valida que a duração está em um range válido."""
        if value < 1:
            raise serializers.ValidationError("A duração deve ser no mínimo 1 dia.")
        if value > 365:
            raise serializers.ValidationError("A duração não pode exceder 365 dias.")
        return value
    
    def validate(self, data):
        """Validações que dependem de múltiplos campos."""
        validation_type = data.get('validation_type')
        
        # Validações específicas por tipo de validação
        if validation_type == Mission.ValidationType.TEMPORAL:
            if data.get('requires_consecutive_days') and not data.get('min_consecutive_days'):
                raise serializers.ValidationError({
                    'min_consecutive_days': 'Obrigatório quando requires_consecutive_days é True.'
                })
        
        elif validation_type == Mission.ValidationType.CATEGORY_REDUCTION:
            if not data.get('target_category'):
                raise serializers.ValidationError({
                    'target_category': 'Obrigatório para missões de redução de categoria.'
                })
            if not data.get('target_reduction_percent'):
                raise serializers.ValidationError({
                    'target_reduction_percent': 'Obrigatório para missões de redução de categoria.'
                })
        
        elif validation_type == Mission.ValidationType.CATEGORY_LIMIT:
            if not data.get('target_category'):
                raise serializers.ValidationError({
                    'target_category': 'Obrigatório para missões de limite de categoria.'
                })
            if not data.get('category_spending_limit'):
                raise serializers.ValidationError({
                    'category_spending_limit': 'Obrigatório para missões de limite de categoria.'
                })
        
        elif validation_type == Mission.ValidationType.GOAL_PROGRESS:
            if not data.get('target_goal'):
                raise serializers.ValidationError({
                    'target_goal': 'Obrigatório para missões de progresso em meta.'
                })
            if not data.get('goal_progress_target'):
                raise serializers.ValidationError({
                    'goal_progress_target': 'Obrigatório para missões de progresso em meta.'
                })
        
        elif validation_type == Mission.ValidationType.SAVINGS_INCREASE:
            if not data.get('savings_increase_amount'):
                raise serializers.ValidationError({
                    'savings_increase_amount': 'Obrigatório para missões de aumento de poupança.'
                })
        
        elif validation_type == Mission.ValidationType.CONSISTENCY:
            if data.get('requires_daily_action') and not data.get('min_daily_actions'):
                raise serializers.ValidationError({
                    'min_daily_actions': 'Obrigatório quando requires_daily_action é True.'
                })
        
        return data


class MissionProgressSerializer(serializers.ModelSerializer):
    mission = MissionSerializer(read_only=True)
    mission_id = serializers.PrimaryKeyRelatedField(
        queryset=Mission.objects.all(), source="mission", write_only=True
    )
    # Campos calculados
    days_remaining = serializers.SerializerMethodField()
    progress_percentage = serializers.SerializerMethodField()
    current_vs_initial = serializers.SerializerMethodField()
    detailed_metrics = serializers.SerializerMethodField()
    progress_status = serializers.SerializerMethodField()

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
            "detailed_metrics",
            "progress_status",
            # Novos campos de rastreamento avançado
            "baseline_category_spending",
            "baseline_period_days",
            "initial_goal_progress",
            "initial_savings_amount",
            "current_streak",
            "max_streak",
            "days_met_criteria",
            "days_violated_criteria",
            "last_violation_date",
            "validation_details",
        )
        read_only_fields = (
            "initial_tps",
            "initial_rdr",
            "initial_ili",
            "initial_transaction_count",
            "days_remaining",
            "progress_percentage",
            "current_vs_initial",
            "detailed_metrics",
            "progress_status",
            "baseline_category_spending",
            "baseline_period_days",
            "initial_goal_progress",
            "initial_savings_amount",
            "current_streak",
            "max_streak",
            "days_met_criteria",
            "days_violated_criteria",
            "last_violation_date",
            "validation_details",
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
    
    def get_detailed_metrics(self, obj):
        """Retorna métricas detalhadas usando o validator específico."""
        try:
            from .mission_types import MissionValidatorFactory
            
            validator = MissionValidatorFactory.create_validator(
                obj.mission,
                obj.user,
                obj
            )
            
            result = validator.calculate_progress()
            return result.get('metrics', {})
            
        except Exception as e:
            return {'error': str(e)}
    
    def get_progress_status(self, obj):
        """Retorna status detalhado do progresso."""
        try:
            from .mission_types import MissionValidatorFactory
            
            validator = MissionValidatorFactory.create_validator(
                obj.mission,
                obj.user,
                obj
            )
            
            result = validator.calculate_progress()
            
            return {
                'message': result.get('message', ''),
                'is_completed': result.get('is_completed', False),
                'can_complete': float(obj.progress) >= 100.0,
                'on_track': float(obj.progress) > 0
            }
            
        except Exception as e:
            return {
                'message': f'Erro ao calcular: {str(e)}',
                'is_completed': False,
                'can_complete': False,
                'on_track': False
            }
    
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


class UserDailySnapshotSerializer(serializers.ModelSerializer):
    """Serializer para snapshots diários do usuário."""
    
    class Meta:
        model = UserDailySnapshot
        fields = (
            "id",
            "snapshot_date",
            "tps",
            "rdr",
            "ili",
            "total_income",
            "total_expense",
            "total_debt",
            "available_balance",
            "category_spending",
            "savings_added_today",
            "savings_total",
            "goals_progress",
            "transactions_registered_today",
            "transaction_count_today",
            "total_transactions_lifetime",
            "budget_exceeded",
            "budget_violations",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")


class UserMonthlySnapshotSerializer(serializers.ModelSerializer):
    """Serializer para snapshots mensais consolidados."""
    
    class Meta:
        model = UserMonthlySnapshot
        fields = (
            "id",
            "year",
            "month",
            "avg_tps",
            "avg_rdr",
            "avg_ili",
            "total_income",
            "total_expense",
            "total_savings",
            "top_category",
            "top_category_amount",
            "category_spending",
            "days_with_transactions",
            "days_in_month",
            "consistency_rate",
            "created_at",
        )
        read_only_fields = ("id", "created_at")


class MissionProgressSnapshotSerializer(serializers.ModelSerializer):
    """Serializer para snapshots de progresso de missões."""
    
    class Meta:
        model = MissionProgressSnapshot
        fields = (
            "id",
            "snapshot_date",
            "tps_value",
            "rdr_value",
            "ili_value",
            "category_spending",
            "goal_progress",
            "goal_current_amount",
            "savings_amount",
            "met_criteria",
            "criteria_details",
            "consecutive_days_met",
            "progress_percentage",
            "created_at",
        )
        read_only_fields = ("id", "created_at")


class DashboardSummarySerializer(serializers.Serializer):
    tps = serializers.DecimalField(max_digits=6, decimal_places=2)
    rdr = serializers.DecimalField(max_digits=6, decimal_places=2)
    ili = serializers.DecimalField(max_digits=6, decimal_places=2)
    total_income = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_expense = serializers.DecimalField(max_digits=12, decimal_places=2)


class CategoryBreakdownSerializer(serializers.Serializer):
    name = serializers.CharField()
    total = serializers.DecimalField(max_digits=12, decimal_places=2)
    group = serializers.CharField()


class CashflowPointSerializer(serializers.Serializer):
    month = serializers.CharField()
    income = serializers.DecimalField(max_digits=12, decimal_places=2)
    expense = serializers.DecimalField(max_digits=12, decimal_places=2)
    tps = serializers.DecimalField(max_digits=6, decimal_places=2)
    rdr = serializers.DecimalField(max_digits=6, decimal_places=2)
    is_projection = serializers.BooleanField(default=False)


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
        
        # Construir nome completo ou usar first_name, fallback para username
        full_name = f"{user.first_name} {user.last_name}".strip() if user.first_name or user.last_name else user.username
        
        return {
            'id': user.id,
            'username': user.username,
            'name': full_name,
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
        
        # Construir nome completo ou usar first_name, fallback para username
        full_name = f"{friend.first_name} {friend.last_name}".strip() if friend.first_name or friend.last_name else friend.username
        
        return {
            'id': friend.id,
            'username': friend.username,
            'name': full_name,
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


class AchievementSerializer(serializers.ModelSerializer):
    """Serializer para conquistas do sistema."""
    
    class Meta:
        model = Achievement
        fields = [
            'id', 'title', 'description', 'category', 'tier',
            'xp_reward', 'icon', 'criteria', 'is_active',
            'is_ai_generated', 'priority', 'created_at'
        ]
        read_only_fields = ['created_at']


class UserAchievementSerializer(serializers.ModelSerializer):
    """Serializer para conquistas do usuário com progresso."""
    achievement = AchievementSerializer(read_only=True)
    progress_percentage = serializers.SerializerMethodField()
    
    class Meta:
        model = UserAchievement
        fields = [
            'id', 'achievement', 'is_unlocked', 'progress',
            'progress_max', 'progress_percentage', 'unlocked_at',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['created_at', 'updated_at']
    
    def get_progress_percentage(self, obj):
        """Retorna progresso em porcentagem."""
        return obj.progress_percentage()
