"""
Serializers para os modelos Mission e MissionProgress.

Este módulo contém os serializers responsáveis pela conversão
entre os modelos de missão e suas representações JSON para a API.

Desenvolvido como parte do TCC - Sistema de Educação Financeira Gamificada.
"""

from .base import serializers, timezone, Mission, MissionProgress, Category, Goal
from .category import CategorySerializer


class MissionSerializer(serializers.ModelSerializer):
    """
    Serializer para o modelo Mission.

    Responsável pela serialização e validação das missões financeiras,
    incluindo campos computados como displays formatados e informações
    sobre a origem da missão (sistema, template ou IA).

    Campos adicionais:
        type_display: Nome legível do tipo de missão.
        difficulty_display: Nome legível do nível de dificuldade.
        validation_type_display: Nome legível do tipo de validação.
        source: Origem da missão (system, template ou ai).
    """
    
    type_display = serializers.CharField(source='get_mission_type_display', read_only=True)
    difficulty_display = serializers.CharField(source='get_difficulty_display', read_only=True)
    validation_type_display = serializers.CharField(source='get_validation_type_display', read_only=True)
    source = serializers.SerializerMethodField()
    target_categories = CategorySerializer(many=True, read_only=True)
    target_category = CategorySerializer(read_only=True)
    
    # Campos de escrita para ForeignKeys
    target_category_id = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.all(),
        source='target_category',
        write_only=True,
        required=False,
        allow_null=True,
    )
    target_goal_id = serializers.PrimaryKeyRelatedField(
        queryset=Goal.objects.all(),
        source='target_goal',
        write_only=True,
        required=False,
        allow_null=True,
    )
    target_categories_ids = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.all(),
        source='target_categories',
        write_only=True,
        many=True,
        required=False,
    )
    target_goals_ids = serializers.PrimaryKeyRelatedField(
        queryset=Goal.objects.all(),
        source='target_goals',
        write_only=True,
        many=True,
        required=False,
    )
    
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
            "target_category_id",
            "target_reduction_percent",
            "category_spending_limit",
            "target_goal",
            "target_goal_id",
            "goal_progress_target",
            "savings_increase_amount",
            "requires_daily_action",
            "min_daily_actions",
            "impacts",
            "tips",
            "min_transaction_frequency",
            "transaction_type_filter",
            "target_categories",
            "target_categories_ids",
            "target_goals_ids",
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
        if obj.is_system_generated:
            return "system"
        elif obj.priority >= 90:
            return "system"
        elif obj.priority >= 5:
            return "template"
        else:
            return "ai"
    
    def get_target_info(self, obj):
        info = {
            'type': obj.mission_type,
            'validation_type': obj.validation_type,
            'targets': []
        }
        
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
        
        if obj.min_transactions is not None:
            info['targets'].append({
                'metric': 'TRANSACTIONS',
                'label': 'Transações',
                'value': obj.min_transactions,
                'unit': 'registros',
                'icon': '📝'
            })
        
        if obj.target_category:
            info['targets'].append({
                'metric': 'CATEGORY',
                'label': obj.target_category.name,
                'category_id': obj.target_category.id,
                'icon': '📁'
            })
        
        if obj.target_categories.exists():
            info['targets'].append({
                'metric': 'CATEGORIES',
                'label': f'{obj.target_categories.count()} categorias',
                'count': obj.target_categories.count(),
                'icon': '📂'
            })
        
        if obj.target_goal:
            info['targets'].append({
                'metric': 'GOAL',
                'label': obj.target_goal.title,
                'goal_id': obj.target_goal.id,
                'icon': '🎯'
            })
        
        if obj.target_goals.exists():
            info['targets'].append({
                'metric': 'GOALS',
                'label': f'{obj.target_goals.count()} metas',
                'count': obj.target_goals.count(),
                'icon': '🎯'
            })
        
        if obj.min_transaction_frequency:
            info['targets'].append({
                'metric': 'FREQUENCY',
                'label': 'Transações por semana',
                'value': obj.min_transaction_frequency,
                'unit': 'por semana',
                'icon': '📊'
            })
        
        if obj.min_payments_count:
            info['targets'].append({
                'metric': 'PAYMENTS',
                'label': 'Pagamentos',
                'value': obj.min_payments_count,
                'unit': 'pagamentos',
                'icon': '💳'
            })
        
        if obj.target_reduction_percent:
            info['targets'].append({
                'metric': 'REDUCTION',
                'label': 'Redução de gastos',
                'value': float(obj.target_reduction_percent),
                'unit': '%',
                'icon': '📉'
            })
        
        if obj.category_spending_limit:
            info['targets'].append({
                'metric': 'LIMIT',
                'label': 'Limite de gastos',
                'value': float(obj.category_spending_limit),
                'unit': 'R$',
                'icon': '💰'
            })
        
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
        if not value or not value.strip():
            raise serializers.ValidationError("O título não pode estar vazio.")
        if len(value) > 150:
            raise serializers.ValidationError("O título não pode ter mais de 150 caracteres.")
        return value.strip()
    
    def validate_description(self, value):
        if not value or not value.strip():
            raise serializers.ValidationError("A descrição não pode estar vazia.")
        return value.strip()
    
    def validate_reward_points(self, value):
        if value < 10:
            raise serializers.ValidationError("A recompensa deve ser no mínimo 10 XP.")
        if value > 1000:
            raise serializers.ValidationError("A recompensa não pode exceder 1000 XP.")
        return value
    
    def validate_duration_days(self, value):
        if value < 1:
            raise serializers.ValidationError("A duração deve ser no mínimo 1 dia.")
        if value > 365:
            raise serializers.ValidationError("A duração não pode exceder 365 dias.")
        return value
    
    def validate(self, data):
        """
        Valida campos obrigatórios baseados no validation_type.
        
        Tipos de validação disponíveis no enum:
        - TRANSACTION_COUNT: Contar transações registradas
        - INDICATOR_THRESHOLD: Verificar se indicador atingiu valor
        - CATEGORY_REDUCTION: Verificar % de redução em categoria
        - GOAL_PROGRESS: Verificar % de progresso em meta
        - TEMPORAL: Manter critério por X dias
        """
        validation_type = data.get('validation_type')
        
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
        
        elif validation_type == Mission.ValidationType.GOAL_PROGRESS:
            if not data.get('target_goal'):
                raise serializers.ValidationError({
                    'target_goal': 'Obrigatório para missões de progresso em meta.'
                })
            if not data.get('goal_progress_target'):
                raise serializers.ValidationError({
                    'goal_progress_target': 'Obrigatório para missões de progresso em meta.'
                })
        
        elif validation_type == Mission.ValidationType.INDICATOR_THRESHOLD:
            # Para INDICATOR_THRESHOLD, validar que pelo menos um indicador alvo foi definido
            has_indicator_target = any([
                data.get('target_tps') is not None,
                data.get('target_rdr') is not None,
                data.get('min_ili') is not None,
                data.get('max_ili') is not None,
            ])
            if not has_indicator_target:
                raise serializers.ValidationError({
                    'non_field_errors': 'Missões de indicador requerem pelo menos um target (TPS, RDR ou ILI).'
                })
        
        elif validation_type == Mission.ValidationType.TRANSACTION_COUNT:
            if not data.get('min_transactions'):
                raise serializers.ValidationError({
                    'min_transactions': 'Obrigatório para missões de contagem de transações.'
                })
        
        # Validações adicionais para campos de ações diárias (aplicável a qualquer tipo)
        if data.get('requires_daily_action') and not data.get('min_daily_actions'):
                raise serializers.ValidationError({
                    'min_daily_actions': 'Obrigatório quando requires_daily_action é True.'
                })
        
        return data


class MissionProgressSerializer(serializers.ModelSerializer):
    """Serializer para progresso em missões."""
    
    mission = MissionSerializer(read_only=True)
    mission_id = serializers.PrimaryKeyRelatedField(
        queryset=Mission.objects.all(), source="mission", write_only=True
    )
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
        if not obj.started_at or not obj.mission.duration_days:
            return None
        
        deadline = obj.started_at + timezone.timedelta(days=obj.mission.duration_days)
        delta = deadline - timezone.now()
        return max(0, delta.days)
    
    def get_progress_percentage(self, obj):
        return f"{float(obj.progress):.1f}%"
    
    def get_detailed_metrics(self, obj):
        if not obj.started_at:
            return None
            
        try:
            from ..mission_types import MissionValidatorFactory
            
            validator = MissionValidatorFactory.create_validator(
                obj.mission,
                obj.user,
                obj
            )
            
            result = validator.calculate_progress()
            raw_metrics = result.get('metrics', {})
            
            if not raw_metrics or 'error' in str(raw_metrics):
                return None
            
            formatted_metrics = self._format_metrics(raw_metrics, obj.mission)
            return formatted_metrics
            
        except Exception:
            return None
    
    def _format_metrics(self, metrics, mission):
        formatted = []
        
        if 'transactions_registered' in metrics:
            formatted.append({
                'label': 'Transações Registradas',
                'value': metrics['transactions_registered'],
                'display': f"{metrics['transactions_registered']} transações",
                'type': 'count',
                'icon': '📝'
            })
        
        if 'target_transactions' in metrics:
            formatted.append({
                'label': 'Meta de Transações',
                'value': metrics['target_transactions'],
                'display': f"{metrics['target_transactions']} transações",
                'type': 'target',
                'icon': '🎯'
            })
        
        if 'remaining' in metrics:
            formatted.append({
                'label': 'Faltam',
                'value': metrics['remaining'],
                'display': f"{metrics['remaining']} {'transações' if metrics['remaining'] != 1 else 'transação'}",
                'type': 'remaining',
                'icon': '⏳'
            })
        
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
        
        if 'category_name' in metrics:
            formatted.append({
                'label': 'Categoria',
                'value': metrics['category_name'],
                'display': metrics['category_name'],
                'type': 'text',
                'icon': '📁'
            })
        
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
        try:
            from ..mission_types import MissionValidatorFactory
            
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
        from ..services import calculate_summary
        
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
                'change': float(obj.initial_rdr) - float(summary.get('rdr', 0)),
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
