from decimal import Decimal
from django.db.models import Q
from django.utils import timezone
from rest_framework import serializers

from .models import (
    Category,
    Goal,
    Mission,
    MissionProgress,
    Transaction,
    TransactionLink,
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
        import re
        if not value:
            return '#808080'
        
        if not re.match(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$', value):
            raise serializers.ValidationError(
                'Cor deve estar no formato hexadecimal (#RRGGBB ou #RGB).'
            )
        
        return value.upper()
    
    def validate_name(self, value):
        if not value or not value.strip():
            raise serializers.ValidationError("Nome da categoria obrigatório.")
        if len(value) > 100:
            raise serializers.ValidationError("Nome não pode exceder 100 caracteres.")
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

        amount = attrs.get('amount', getattr(instance, 'amount', None))
        if amount is not None and amount <= 0:
            raise serializers.ValidationError({
                'amount': 'Valor deve ser maior que zero.'
            })
        
        max_amount = Decimal('999999999.99')
        if amount is not None and amount > max_amount:
            raise serializers.ValidationError({
                'amount': f'Valor excede o limite permitido: R$ {max_amount:,.2f}'
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
                    "Frequência obrigatória para transações recorrentes.",
                )
            if recurrence_value > 365:
                raise serializers.ValidationError({
                    'recurrence_value': 'Valor de recorrência excede o limite.'
                })
        else:
            attrs["recurrence_value"] = None
            attrs["recurrence_unit"] = None
            attrs["recurrence_end_date"] = None
            if "is_recurring" in attrs:
                attrs["is_recurring"] = False
        
        from django.utils import timezone
        from datetime import timedelta
        
        date = attrs.get('date', getattr(instance, 'date', None))
        if date:
            max_future_date = timezone.now().date() + timedelta(days=365)
            if date > max_future_date:
                raise serializers.ValidationError({
                    'date': 'Data não pode exceder 1 ano no futuro.'
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
        """Retorna métricas detalhadas formatadas usando o validator específico."""
        # Se missão não foi iniciada, não retornar métricas
        if not obj.started_at:
            return None
            
        try:
            from .mission_types import MissionValidatorFactory
            
            validator = MissionValidatorFactory.create_validator(
                obj.mission,
                obj.user,
                obj
            )
            
            result = validator.calculate_progress()
            raw_metrics = result.get('metrics', {})
            
            # Se as métricas estão vazias ou indicam erro, retornar None
            if not raw_metrics or 'error' in str(raw_metrics):
                return None
            
            # Formatar métricas para exibição
            formatted_metrics = self._format_metrics(raw_metrics, obj.mission)
            return formatted_metrics
            
        except Exception as e:
            return None
    
    def _format_metrics(self, metrics, mission):
        """Formata métricas brutas para exibição amigável."""
        formatted = []
        
        # Transações registradas
        if 'transactions_registered' in metrics:
            formatted.append({
                'label': 'Transações Registradas',
                'value': metrics['transactions_registered'],
                'display': f"{metrics['transactions_registered']} transações",
                'type': 'count',
                'icon': '📝'
            })
        
        # Meta de transações
        if 'target_transactions' in metrics:
            formatted.append({
                'label': 'Meta de Transações',
                'value': metrics['target_transactions'],
                'display': f"{metrics['target_transactions']} transações",
                'type': 'target',
                'icon': '🎯'
            })
        
        # Restante
        if 'remaining' in metrics:
            formatted.append({
                'label': 'Faltam',
                'value': metrics['remaining'],
                'display': f"{metrics['remaining']} {'transações' if metrics['remaining'] != 1 else 'transação'}",
                'type': 'remaining',
                'icon': '⏳'
            })
        
        # TPS (Taxa de Poupança)
        if 'current_tps' in metrics:
            formatted.append({
                'label': 'TPS Atual',
                'value': metrics['current_tps'],
                'display': f"{metrics['current_tps']:.1f}%",
                'type': 'percentage',
                'icon': '💰'
            })
        
        if 'target_tps' in metrics:
            formatted.append({
                'label': 'Meta TPS',
                'value': metrics['target_tps'],
                'display': f"{metrics['target_tps']:.1f}%",
                'type': 'target',
                'icon': '🎯'
            })
        
        # RDR (Razão de Despesas Recorrentes)
        if 'current_rdr' in metrics:
            formatted.append({
                'label': 'RDR Atual',
                'value': metrics['current_rdr'],
                'display': f"{metrics['current_rdr']:.1f}%",
                'type': 'percentage',
                'icon': '📉'
            })
        
        if 'target_rdr' in metrics:
            formatted.append({
                'label': 'Meta RDR',
                'value': metrics['target_rdr'],
                'display': f"{metrics['target_rdr']:.1f}%",
                'type': 'target',
                'icon': '🎯'
            })
        
        # ILI (Índice de Liquidez Imediata)
        if 'current_ili' in metrics:
            formatted.append({
                'label': 'ILI Atual',
                'value': metrics['current_ili'],
                'display': f"{metrics['current_ili']:.1f} meses",
                'type': 'months',
                'icon': '🛡️'
            })
        
        if 'target_ili' in metrics:
            formatted.append({
                'label': 'Meta ILI',
                'value': metrics['target_ili'],
                'display': f"{metrics['target_ili']:.1f} meses",
                'type': 'target',
                'icon': '🎯'
            })
        
        # Categoria
        if 'category_name' in metrics:
            formatted.append({
                'label': 'Categoria',
                'value': metrics['category_name'],
                'display': metrics['category_name'],
                'type': 'text',
                'icon': '📁'
            })
        
        # Gastos
        if 'current_spending' in metrics:
            formatted.append({
                'label': 'Gasto Atual',
                'value': metrics['current_spending'],
                'display': f"R$ {metrics['current_spending']:.2f}",
                'type': 'currency',
                'icon': '💸'
            })
        
        if 'reference_spending' in metrics:
            formatted.append({
                'label': 'Gasto Anterior',
                'value': metrics['reference_spending'],
                'display': f"R$ {metrics['reference_spending']:.2f}",
                'type': 'currency',
                'icon': '📊'
            })
        
        # Redução percentual
        if 'reduction_percent' in metrics:
            value = metrics['reduction_percent']
            formatted.append({
                'label': 'Redução Alcançada',
                'value': value,
                'display': f"{value:.1f}%",
                'type': 'percentage',
                'icon': '📉' if value > 0 else '📈'
            })
        
        if 'target_reduction' in metrics:
            formatted.append({
                'label': 'Meta de Redução',
                'value': metrics['target_reduction'],
                'display': f"{metrics['target_reduction']:.1f}%",
                'type': 'target',
                'icon': '🎯'
            })
        
        # Meta (Goal)
        if 'goal_name' in metrics:
            formatted.append({
                'label': 'Meta',
                'value': metrics['goal_name'],
                'display': metrics['goal_name'],
                'type': 'text',
                'icon': '🎯'
            })
        
        if 'current_amount' in metrics:
            formatted.append({
                'label': 'Valor Atual',
                'value': metrics['current_amount'],
                'display': f"R$ {metrics['current_amount']:.2f}",
                'type': 'currency',
                'icon': '💰'
            })
        
        if 'target_amount' in metrics:
            formatted.append({
                'label': 'Valor Meta',
                'value': metrics['target_amount'],
                'display': f"R$ {metrics['target_amount']:.2f}",
                'type': 'currency',
                'icon': '🎯'
            })
        
        if 'goal_progress' in metrics:
            formatted.append({
                'label': 'Progresso da Meta',
                'value': metrics['goal_progress'],
                'display': f"{metrics['goal_progress']:.1f}%",
                'type': 'percentage',
                'icon': '📈'
            })
        
        # Contribuições
        if 'contributions' in metrics:
            formatted.append({
                'label': 'Contribuído',
                'value': metrics['contributions'],
                'display': f"R$ {metrics['contributions']:.2f}",
                'type': 'currency',
                'icon': '💰'
            })
        
        if 'target_contribution' in metrics:
            formatted.append({
                'label': 'Meta de Contribuição',
                'value': metrics['target_contribution'],
                'display': f"R$ {metrics['target_contribution']:.2f}",
                'type': 'currency',
                'icon': '🎯'
            })
        
        # Semanas/Dias
        if 'weeks_meeting_criteria' in metrics:
            formatted.append({
                'label': 'Semanas Completas',
                'value': metrics['weeks_meeting_criteria'],
                'display': f"{metrics['weeks_meeting_criteria']} semanas",
                'type': 'count',
                'icon': '📅'
            })
        
        if 'target_weeks' in metrics:
            formatted.append({
                'label': 'Meta de Semanas',
                'value': metrics['target_weeks'],
                'display': f"{metrics['target_weeks']} semanas",
                'type': 'target',
                'icon': '🎯'
            })
        
        if 'days_maintained' in metrics:
            formatted.append({
                'label': 'Dias Mantidos',
                'value': metrics['days_maintained'],
                'display': f"{metrics['days_maintained']} dias",
                'type': 'count',
                'icon': '📆'
            })
        
        if 'target_days' in metrics:
            formatted.append({
                'label': 'Meta de Dias',
                'value': metrics['target_days'],
                'display': f"{metrics['target_days']} dias",
                'type': 'target',
                'icon': '🎯'
            })
        
        # Pagamentos
        if 'payments_count' in metrics:
            formatted.append({
                'label': 'Pagamentos Registrados',
                'value': metrics['payments_count'],
                'display': f"{metrics['payments_count']} pagamentos",
                'type': 'count',
                'icon': '💳'
            })
        
        if 'target_payments' in metrics:
            formatted.append({
                'label': 'Meta de Pagamentos',
                'value': metrics['target_payments'],
                'display': f"{metrics['target_payments']} pagamentos",
                'type': 'target',
                'icon': '🎯'
            })
        
        return formatted
    
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
    
    cached_tps = serializers.DecimalField(
        max_digits=5, decimal_places=2, read_only=True, required=False
    )
    cached_rdr = serializers.DecimalField(
        max_digits=5, decimal_places=2, read_only=True, required=False
    )
    cached_ili = serializers.DecimalField(
        max_digits=12, decimal_places=2, read_only=True, required=False
    )
    cache_timestamp = serializers.DateTimeField(read_only=True, required=False)

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
            "cached_tps",
            "cached_rdr",
            "cached_ili",
            "cache_timestamp",
        )
        read_only_fields = (
            "level", 
            "experience_points", 
            "next_level_threshold",
            "cached_tps",
            "cached_rdr",
            "cached_ili",
            "cache_timestamp",
        )


class DashboardSerializer(serializers.Serializer):
    summary = DashboardSummarySerializer()
    categories = serializers.DictField(child=CategoryBreakdownSerializer(many=True))
    cashflow = CashflowPointSerializer(many=True)
    insights = serializers.DictField(child=IndicatorInsightSerializer())
    active_missions = MissionProgressSerializer(many=True)
    recommended_missions = MissionSerializer(many=True)
    profile = UserProfileSerializer()


class TransactionLinkSerializer(serializers.ModelSerializer):
    
    source_transaction = TransactionSerializer(read_only=True)
    target_transaction = TransactionSerializer(read_only=True)
    
    source_uuid = serializers.UUIDField(write_only=True, required=True)
    target_uuid = serializers.UUIDField(write_only=True, required=True)
    
    source_description = serializers.SerializerMethodField()
    target_description = serializers.SerializerMethodField()
    formatted_amount = serializers.SerializerMethodField()
    display_name = serializers.SerializerMethodField()
    payment_status = serializers.SerializerMethodField()
    urgency_score = serializers.SerializerMethodField()
    
    class Meta:
        model = TransactionLink
        fields = (
            'id',
            'source_transaction',
            'target_transaction',
            'source_uuid',
            'target_uuid',
            'linked_amount',
            'link_type',
            'description',
            'is_recurring',
            'created_at',
            'updated_at',
            'source_description',
            'target_description',
            'formatted_amount',
            'display_name',
            'payment_status',
            'urgency_score',
        )
        read_only_fields = (
            'id',
            'created_at',
            'updated_at',
            'source_description',
            'target_description',
            'formatted_amount',
            'display_name',
            'payment_status',
            'urgency_score',
        )
    
    def get_source_description(self, obj):
        return obj.source_transaction.description if obj.source_transaction else None
    
    def get_target_description(self, obj):
        return obj.target_transaction.description if obj.target_transaction else None
    
    def get_formatted_amount(self, obj):
        return f"R$ {obj.linked_amount:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.')
    
    def get_display_name(self, obj):
        link_type_labels = {
            TransactionLink.LinkType.EXPENSE_PAYMENT: "Pagamento",
            TransactionLink.LinkType.INTERNAL_TRANSFER: "Transferência",
            TransactionLink.LinkType.SAVINGS_ALLOCATION: "Poupança",
        }
        
        type_label = link_type_labels.get(obj.link_type, "Vinculação")
        source_name = obj.source_transaction.description[:30] if obj.source_transaction else "Origem"
        target_name = obj.target_transaction.description[:30] if obj.target_transaction else "Destino"
        
        return f"{type_label}: {source_name} → {target_name}"
    
    def get_payment_status(self, obj):
        if not obj.target_transaction:
            return "unknown"
        
        target = obj.target_transaction
        if target.type != Transaction.TransactionType.EXPENSE:
            return "not_applicable"
        
        available = target.available_amount
        if available == 0:
            return "complete"
        elif available < target.amount * Decimal('0.5'):
            return "partial_high"
        else:
            return "partial_low"
    
    def get_urgency_score(self, obj):
        from django.utils import timezone
        
        if not obj.target_transaction:
            return 0
        
        target = obj.target_transaction
        if target.type != Transaction.TransactionType.EXPENSE:
            return 0
        
        score = 0
        
        days_old = (timezone.now() - target.created_at).days
        if days_old >= 30:
            score += 40
        elif days_old >= 15:
            score += 25
        elif days_old >= 7:
            score += 10
        
        payment_pct = float(target.link_percentage)
        if payment_pct >= 80:
            score += 30
        elif payment_pct >= 50:
            score += 20
        elif payment_pct >= 25:
            score += 10
        
        amount = float(target.amount)
        if amount >= 1000:
            score += 20
        elif amount >= 500:
            score += 15
        elif amount >= 100:
            score += 10
        
        if target.is_recurring:
            score += 10
        
        return min(100, score)
    
    def validate(self, attrs):
        from .payment_validator import PaymentValidator
        
        request = self.context.get('request')
        if not request:
            raise serializers.ValidationError("Contexto de requisição não disponível")
        
        user = request.user
        source_uuid = attrs.get('source_uuid')
        target_uuid = attrs.get('target_uuid')
        linked_amount = attrs.get('linked_amount')
        link_type = attrs.get('link_type', TransactionLink.LinkType.EXPENSE_PAYMENT)
        
        try:
            source = Transaction.objects.get(id=source_uuid, user=user)
        except Transaction.DoesNotExist:
            raise serializers.ValidationError({
                "source_uuid": "Transação de origem não encontrada ou não autorizada"
            })
        
        try:
            target = Transaction.objects.get(id=target_uuid, user=user)
        except Transaction.DoesNotExist:
            raise serializers.ValidationError({
                "target_uuid": "Transação de destino não encontrada ou não autorizada"
            })
        
        validator = PaymentValidator(user)
        is_valid, errors = validator.validate_payment(source, target, linked_amount, link_type)
        
        if not is_valid:
            raise serializers.ValidationError(errors)
        
        attrs['source_transaction_uuid'] = source.id
        attrs['target_transaction_uuid'] = target.id
        
        return attrs
    
    def create(self, validated_data):
        from .services import invalidate_indicators_cache
        
        validated_data.pop('source_uuid', None)
        validated_data.pop('target_uuid', None)
        
        request = self.context.get('request')
        validated_data['user'] = request.user
        
        link = TransactionLink.objects.create(**validated_data)
        
        invalidate_indicators_cache(request.user)
        
        return link


class TransactionLinkSummarySerializer(serializers.Serializer):
    transaction_id = serializers.UUIDField()
    transaction_description = serializers.CharField()
    transaction_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    linked_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    available_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    link_percentage = serializers.DecimalField(max_digits=5, decimal_places=2)




